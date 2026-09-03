import json
import os
from typing import Any, Dict, List, Optional

import httpx
from fastapi import FastAPI, Header, HTTPException, Request
from fastapi.responses import PlainTextResponse
from pydantic import BaseModel, Field

try:
    from dotenv import load_dotenv

    load_dotenv()
except ImportError:
    pass


app = FastAPI(title="NeuroGuardian X Emergency Backend")


class Guardian(BaseModel):
    phone: str = ""
    push_target: str = ""


class Location(BaseModel):
    latitude: float
    longitude: float
    accuracy_m: Optional[float] = None
    maps_link: str = ""
    nearby_hospitals_link: str = ""


class Facility(BaseModel):
    name: str
    address: str = "Address unavailable"
    phone: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    mapsUri: Optional[str] = None


class EmergencyAlert(BaseModel):
    event_type: str
    reason: str
    message: str
    summary: str = ""
    channels: List[str] = Field(default_factory=lambda: ["whatsapp", "push"])
    guardian: Guardian = Field(default_factory=Guardian)
    ambulance_phone: str = ""
    location: Location
    medical_facilities: List[Facility] = Field(default_factory=list)
    vitals: Dict[str, Any] = Field(default_factory=dict)
    created_at: str = ""


class NearbyRequest(BaseModel):
    latitude: float
    longitude: float
    max_results: int = 3


def _model_dump(model: BaseModel) -> Dict[str, Any]:
    if hasattr(model, "model_dump"):
        return model.model_dump()
    return model.dict()


def _require_device_token(authorization: Optional[str]) -> None:
    expected = os.getenv("NGX_DEVICE_TOKEN", "").strip()
    if not expected:
        return
    if authorization != f"Bearer {expected}":
        raise HTTPException(status_code=401, detail="Invalid device token")


def _places_api_key() -> str:
    return (
        os.getenv("GOOGLE_PLACES_API_KEY", "").strip()
        or os.getenv("GOOGLE_MAPS_API_KEY", "").strip()
    )


def _webhook_verify_token() -> str:
    return (
        os.getenv("WHATSAPP_WEBHOOK_VERIFY_TOKEN", "").strip()
        or os.getenv("WHATSAPP_CLOUD_WEBHOOK_VERIFY_TOKEN", "").strip()
    )


def _maps_link(latitude: float, longitude: float) -> str:
    return f"https://maps.google.com/?q={latitude},{longitude}"


def _clip(value: str, limit: int) -> str:
    return value if len(value) <= limit else f"{value[: limit - 3]}..."


def _whatsapp_number(phone: str) -> str:
    return "".join(ch for ch in phone if ch.isdigit())


def _e164_phone(phone: str) -> str:
    cleaned = "".join(ch for ch in phone if ch.isdigit() or ch == "+")
    digits = _whatsapp_number(cleaned)
    if cleaned.startswith("+"):
        return cleaned
    return f"+{digits}" if digits else ""


def _facility_line(facility: Facility) -> str:
    phone = f", {facility.phone}" if facility.phone else ""
    return f"{facility.name} - {facility.address}{phone}"


def _format_alert(alert: EmergencyAlert, facilities: List[Facility]) -> str:
    facility_text = (
        " | ".join(_facility_line(item) for item in facilities[:3])
        if facilities
        else alert.location.nearby_hospitals_link
    )
    vitals = alert.vitals or {}
    vitals_text = ", ".join(
        f"{key}={value}" for key, value in vitals.items() if value is not None
    )
    return (
        f"{alert.message}\n"
        f"Location: {alert.location.maps_link or _maps_link(alert.location.latitude, alert.location.longitude)}\n"
        f"Nearby medical facilities: {facility_text}\n"
        f"Vitals: {vitals_text or 'not available'}"
    )


def _is_whatsapp_notification(item: Dict[str, Any]) -> bool:
    return str(item.get("channel", "")).lower() in {
        "whatsapp",
        "whatsapp_cloud",
        "twilio_whatsapp",
    }


def _is_push_notification(item: Dict[str, Any]) -> bool:
    return str(item.get("channel", "")).lower() in {"push", "ntfy_push"}


def _whatsapp_template_parameters(
    alert: EmergencyAlert,
    facilities: List[Facility],
) -> List[Dict[str, str]]:
    facility_text = (
        " | ".join(_facility_line(item) for item in facilities[:3])
        if facilities
        else alert.location.nearby_hospitals_link
    )
    vitals = alert.vitals or {}
    vitals_text = ", ".join(
        f"{key}={value}" for key, value in vitals.items() if value is not None
    )
    return [
        {"type": "text", "text": _clip(alert.summary or alert.reason, 900)},
        {
            "type": "text",
            "text": _clip(
                alert.location.maps_link
                or _maps_link(alert.location.latitude, alert.location.longitude),
                900,
            ),
        },
        {"type": "text", "text": _clip(facility_text or "Not available", 900)},
        {"type": "text", "text": _clip(vitals_text or "Not available", 900)},
    ]


async def _fetch_google_facilities(
    latitude: float,
    longitude: float,
    max_results: int = 3,
) -> List[Facility]:
    api_key = _places_api_key()
    if not api_key:
        return []

    payload = {
        "includedTypes": ["hospital"],
        "maxResultCount": max(1, min(max_results, 20)),
        "rankPreference": "DISTANCE",
        "locationRestriction": {
            "circle": {
                "center": {"latitude": latitude, "longitude": longitude},
                "radius": 10000.0,
            }
        },
    }
    headers = {
        "Content-Type": "application/json",
        "X-Goog-Api-Key": api_key,
        "X-Goog-FieldMask": (
            "places.displayName,places.formattedAddress,places.location,"
            "places.nationalPhoneNumber,places.googleMapsUri"
        ),
    }
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            response = await client.post(
                "https://places.googleapis.com/v1/places:searchNearby",
                headers=headers,
                json=payload,
            )
            response.raise_for_status()
            data = response.json()
    except httpx.HTTPError as error:
        print(f"Google Places lookup failed: {error}")
        return []

    facilities: List[Facility] = []
    for place in data.get("places", [])[:max_results]:
        location = place.get("location") or {}
        display_name = place.get("displayName") or {}
        facilities.append(
            Facility(
                name=display_name.get("text") or "Medical facility",
                address=place.get("formattedAddress") or "Address unavailable",
                phone=place.get("nationalPhoneNumber"),
                latitude=location.get("latitude"),
                longitude=location.get("longitude"),
                mapsUri=place.get("googleMapsUri"),
            )
        )
    return facilities


async def _post_supersend(
    channel: str,
    alert: EmergencyAlert,
    facilities: List[Facility],
) -> Dict[str, Any]:
    api_key = os.getenv("SUPERSEND_API_KEY", "").strip()
    base_url = os.getenv("SUPERSEND_BASE_URL", "https://api.supersend.io/v2").rstrip("/")
    endpoint_env = (
        "SUPERSEND_WHATSAPP_ENDPOINT"
        if channel == "whatsapp"
        else "SUPERSEND_PUSH_ENDPOINT"
    )
    endpoint = os.getenv(endpoint_env, "").strip()
    target = (
        alert.guardian.phone if channel == "whatsapp" else alert.guardian.push_target
    )

    if not target:
        return {
            "channel": channel,
            "sent": False,
            "dry_run": True,
            "reason": "guardian target is empty",
        }
    if not api_key or not endpoint:
        return {
            "channel": channel,
            "sent": False,
            "dry_run": True,
            "reason": f"{endpoint_env} or SUPERSEND_API_KEY is not configured",
        }

    url = endpoint if endpoint.startswith("http") else f"{base_url}/{endpoint.lstrip('/')}"
    message = _format_alert(alert, facilities)
    payload = {
        "to": target,
        "target": target,
        "recipient": target,
        "channel": channel,
        "message": message,
        "text": message,
        "subject": "NeuroGuardian X emergency alert",
        "data": {
            "event_type": alert.event_type,
            "reason": alert.reason,
            "location": _model_dump(alert.location),
            "medical_facilities": [_model_dump(item) for item in facilities],
            "vitals": alert.vitals,
            "created_at": alert.created_at,
        },
    }
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }
    try:
        async with httpx.AsyncClient(timeout=12) as client:
            response = await client.post(url, headers=headers, json=payload)
    except httpx.HTTPError as error:
        return {
            "channel": channel,
            "sent": False,
            "dry_run": False,
            "reason": f"SuperSend request failed: {error}",
        }

    sent = 200 <= response.status_code < 300
    return {
        "channel": channel,
        "sent": sent,
        "status_code": response.status_code,
        "body": response.text[:500],
    }


async def _post_whatsapp_cloud(
    alert: EmergencyAlert,
    facilities: List[Facility],
) -> Dict[str, Any]:
    access_token = os.getenv("WHATSAPP_CLOUD_ACCESS_TOKEN", "").strip()
    phone_number_id = os.getenv("WHATSAPP_CLOUD_PHONE_NUMBER_ID", "").strip()
    graph_version = os.getenv("WHATSAPP_GRAPH_VERSION", "v23.0").strip()
    template_name = os.getenv("WHATSAPP_CLOUD_TEMPLATE_NAME", "").strip()
    language = os.getenv("WHATSAPP_CLOUD_TEMPLATE_LANGUAGE", "en_US").strip()
    allow_text = os.getenv("WHATSAPP_CLOUD_ALLOW_TEXT", "false").lower() == "true"
    to_number = _whatsapp_number(alert.guardian.phone)

    if not to_number:
        return {
            "channel": "whatsapp_cloud",
            "sent": False,
            "dry_run": True,
            "reason": "guardian WhatsApp phone is empty",
        }
    if not access_token or not phone_number_id:
        return {
            "channel": "whatsapp_cloud",
            "sent": False,
            "dry_run": True,
            "reason": "WHATSAPP_CLOUD_ACCESS_TOKEN or WHATSAPP_CLOUD_PHONE_NUMBER_ID is not configured",
        }

    url = f"https://graph.facebook.com/{graph_version}/{phone_number_id}/messages"
    if template_name:
        payload: Dict[str, Any] = {
            "messaging_product": "whatsapp",
            "recipient_type": "individual",
            "to": to_number,
            "type": "template",
            "template": {
                "name": template_name,
                "language": {"code": language},
                "components": [
                    {
                        "type": "body",
                        "parameters": _whatsapp_template_parameters(alert, facilities),
                    }
                ],
            },
        }
    elif allow_text:
        payload = {
            "messaging_product": "whatsapp",
            "recipient_type": "individual",
            "to": to_number,
            "type": "text",
            "text": {
                "preview_url": True,
                "body": _clip(_format_alert(alert, facilities), 3900),
            },
        }
    else:
        return {
            "channel": "whatsapp_cloud",
            "sent": False,
            "dry_run": True,
            "reason": "approved WhatsApp template is not configured",
        }

    try:
        async with httpx.AsyncClient(timeout=12) as client:
            response = await client.post(
                url,
                headers={
                    "Authorization": f"Bearer {access_token}",
                    "Content-Type": "application/json",
                },
                json=payload,
            )
    except httpx.HTTPError as error:
        return {
            "channel": "whatsapp_cloud",
            "sent": False,
            "dry_run": False,
            "reason": f"WhatsApp Cloud request failed: {error}",
        }

    return {
        "channel": "whatsapp_cloud",
        "sent": 200 <= response.status_code < 300,
        "status_code": response.status_code,
        "body": response.text[:500],
        "template": template_name,
    }


async def _post_twilio_whatsapp(
    alert: EmergencyAlert,
    facilities: List[Facility],
) -> Dict[str, Any]:
    account_sid = os.getenv("TWILIO_ACCOUNT_SID", "").strip()
    auth_token = os.getenv("TWILIO_AUTH_TOKEN", "").strip()
    from_number = os.getenv("TWILIO_WHATSAPP_FROM", "").strip()
    messaging_service_sid = os.getenv("TWILIO_MESSAGING_SERVICE_SID", "").strip()
    content_sid = os.getenv("TWILIO_CONTENT_SID", "").strip()
    to_number = _e164_phone(alert.guardian.phone)

    if not to_number:
        return {
            "channel": "twilio_whatsapp",
            "sent": False,
            "dry_run": True,
            "reason": "guardian WhatsApp phone is empty",
        }
    if not account_sid or not auth_token:
        return {
            "channel": "twilio_whatsapp",
            "sent": False,
            "dry_run": True,
            "reason": "TWILIO_ACCOUNT_SID or TWILIO_AUTH_TOKEN is not configured",
        }
    if not from_number and not messaging_service_sid:
        return {
            "channel": "twilio_whatsapp",
            "sent": False,
            "dry_run": True,
            "reason": "TWILIO_WHATSAPP_FROM or TWILIO_MESSAGING_SERVICE_SID is not configured",
        }

    data: Dict[str, str] = {"To": f"whatsapp:{to_number}"}
    if messaging_service_sid:
        data["MessagingServiceSid"] = messaging_service_sid
    else:
        data["From"] = (
            from_number if from_number.startswith("whatsapp:") else f"whatsapp:{from_number}"
        )
    if content_sid:
        parameters = _whatsapp_template_parameters(alert, facilities)
        data["ContentSid"] = content_sid
        data["ContentVariables"] = json.dumps(
            {str(index + 1): item["text"] for index, item in enumerate(parameters)}
        )
    else:
        data["Body"] = _clip(_format_alert(alert, facilities), 1590)

    try:
        async with httpx.AsyncClient(timeout=12) as client:
            response = await client.post(
                f"https://api.twilio.com/2010-04-01/Accounts/{account_sid}/Messages.json",
                data=data,
                auth=(account_sid, auth_token),
            )
    except httpx.HTTPError as error:
        return {
            "channel": "twilio_whatsapp",
            "sent": False,
            "dry_run": False,
            "reason": f"Twilio WhatsApp request failed: {error}",
        }

    return {
        "channel": "twilio_whatsapp",
        "sent": 200 <= response.status_code < 300,
        "status_code": response.status_code,
        "body": response.text[:500],
    }


async def _post_whatsapp(
    alert: EmergencyAlert,
    facilities: List[Facility],
) -> List[Dict[str, Any]]:
    provider = os.getenv("WHATSAPP_PROVIDER", "cloud").strip().lower()
    if provider in {"cloud", "meta", "whatsapp_cloud"}:
        cloud_result = await _post_whatsapp_cloud(alert, facilities)
        if cloud_result.get("sent") or not cloud_result.get("dry_run"):
            return [cloud_result]
        twilio_result = await _post_twilio_whatsapp(alert, facilities)
        if twilio_result.get("sent") or not twilio_result.get("dry_run"):
            return [cloud_result, twilio_result]
        return [cloud_result, twilio_result, await _post_supersend("whatsapp", alert, facilities)]
    if provider == "twilio":
        twilio_result = await _post_twilio_whatsapp(alert, facilities)
        if twilio_result.get("sent") or not twilio_result.get("dry_run"):
            return [twilio_result]
        return [twilio_result, await _post_whatsapp_cloud(alert, facilities)]
    return [await _post_supersend("whatsapp", alert, facilities)]


async def _post_ntfy(alert: EmergencyAlert, facilities: List[Facility]) -> Dict[str, Any]:
    base_url = os.getenv("NTFY_BASE_URL", "https://ntfy.sh").rstrip("/")
    configured_topic = os.getenv("NGX_NTFY_TOPIC", "").strip()
    push_target = alert.guardian.push_target.strip()
    topic = push_target[5:] if push_target.lower().startswith("ntfy:") else configured_topic
    if not topic:
        return {
            "channel": "ntfy_push",
            "sent": False,
            "dry_run": True,
            "reason": "NGX_NTFY_TOPIC is not configured",
        }

    message = _format_alert(alert, facilities)
    headers = {
        "Title": "NeuroGuardian X emergency",
        "Priority": "urgent",
        "Tags": "rotating_light,ambulance",
        "Click": alert.location.maps_link
        or _maps_link(alert.location.latitude, alert.location.longitude),
    }
    try:
        async with httpx.AsyncClient(timeout=12) as client:
            response = await client.post(
                f"{base_url}/{topic}",
                headers=headers,
                content=message.encode("utf-8"),
            )
    except httpx.HTTPError as error:
        return {
            "channel": "ntfy_push",
            "sent": False,
            "dry_run": False,
            "reason": f"ntfy request failed: {error}",
        }

    return {
        "channel": "ntfy_push",
        "sent": 200 <= response.status_code < 300,
        "status_code": response.status_code,
        "body": response.text[:500],
        "topic": topic,
    }


@app.get("/health")
async def health() -> Dict[str, Any]:
    return {
        "ok": True,
        "google_places": bool(_places_api_key()),
        "supersend": bool(os.getenv("SUPERSEND_API_KEY", "").strip()),
        "whatsapp_cloud": bool(
            os.getenv("WHATSAPP_CLOUD_ACCESS_TOKEN", "").strip()
            and os.getenv("WHATSAPP_CLOUD_PHONE_NUMBER_ID", "").strip()
        ),
        "twilio_whatsapp": bool(
            os.getenv("TWILIO_ACCOUNT_SID", "").strip()
            and os.getenv("TWILIO_AUTH_TOKEN", "").strip()
            and (
                os.getenv("TWILIO_WHATSAPP_FROM", "").strip()
                or os.getenv("TWILIO_MESSAGING_SERVICE_SID", "").strip()
            )
        ),
        "ntfy_push": bool(os.getenv("NGX_NTFY_TOPIC", "").strip()),
        "whatsapp_webhook": bool(_webhook_verify_token()),
    }


@app.get("/whatsapp/webhook", response_class=PlainTextResponse)
async def verify_whatsapp_webhook(request: Request) -> PlainTextResponse:
    mode = request.query_params.get("hub.mode", "")
    token = request.query_params.get("hub.verify_token", "")
    challenge = request.query_params.get("hub.challenge", "")
    expected = _webhook_verify_token()

    if mode == "subscribe" and expected and token == expected:
        return PlainTextResponse(challenge)
    raise HTTPException(status_code=403, detail="Webhook verification failed")


@app.post("/whatsapp/webhook")
async def receive_whatsapp_webhook(payload: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "ok": True,
        "received": True,
        "object": payload.get("object"),
    }


@app.post("/medical-facilities/nearby")
async def nearby_facilities(
    request: NearbyRequest,
    authorization: Optional[str] = Header(default=None),
) -> Dict[str, Any]:
    _require_device_token(authorization)
    facilities = await _fetch_google_facilities(
        request.latitude,
        request.longitude,
        request.max_results,
    )
    return {
        "success": bool(facilities),
        "facilities": [_model_dump(item) for item in facilities],
    }


@app.post("/emergency/alert")
async def emergency_alert(
    alert: EmergencyAlert,
    authorization: Optional[str] = Header(default=None),
) -> Dict[str, Any]:
    _require_device_token(authorization)

    facilities = alert.medical_facilities
    if not facilities:
        facilities = await _fetch_google_facilities(
            alert.location.latitude,
            alert.location.longitude,
            3,
        )

    normalized_channels = {item.strip().lower() for item in alert.channels}
    notifications: List[Dict[str, Any]] = []
    for channel in ("whatsapp", "push"):
        if channel in normalized_channels:
            if channel == "whatsapp":
                notifications.extend(await _post_whatsapp(alert, facilities))
            else:
                notifications.append(await _post_supersend(channel, alert, facilities))
            if channel == "push":
                notifications.append(await _post_ntfy(alert, facilities))

    whatsapp_sent = any(
        _is_whatsapp_notification(item) and item.get("sent") for item in notifications
    )
    push_sent = any(
        _is_push_notification(item) and item.get("sent") for item in notifications
    )
    sent = any(item.get("sent") for item in notifications)
    return {
        "success": sent,
        "whatsapp_sent": whatsapp_sent,
        "push_sent": push_sent,
        "delivery": {"whatsapp": whatsapp_sent, "push": push_sent},
        "message": (
            "Emergency WhatsApp and backup notification sent."
            if whatsapp_sent and push_sent
            else "Emergency WhatsApp alert sent."
            if whatsapp_sent
            else "Backup notification sent, but WhatsApp did not send. Check WhatsApp Cloud token, template, or recipient access."
            if push_sent
            else "Emergency alert accepted, but notification channels are in dry-run or failed."
        ),
        "facilities": [_model_dump(item) for item in facilities],
        "notifications": notifications,
    }
