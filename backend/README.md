# NeuroGuardian X Emergency Backend

This backend keeps Google Maps and SuperSend keys out of the Flutter APK.
The app sends one authenticated emergency payload here; the backend enriches it
with nearby hospitals and forwards it to guardian notification channels.

## Run locally

```powershell
cd "C:\Users\hp\Downloads\neuro gardian x\neuroguardian_app\backend"
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
copy .env.example .env
uvicorn emergency_server:app --host 0.0.0.0 --port 8080
```

In the app SOS settings, set:

- Backend URL: `http://YOUR_PC_IP:8080`
- Backend device token: same value as `NGX_DEVICE_TOKEN`
- Guardian phone: WhatsApp-capable guardian number
- Guardian push target: the guardian app/device token or ID used by your push provider

## Environment keys

- `NGX_DEVICE_TOKEN`: app-to-backend safety token.
- `GOOGLE_MAPS_API_KEY` or `GOOGLE_PLACES_API_KEY`: Google Places Nearby Search key.
- `SUPERSEND_API_KEY`: SuperSend API key.
- `SUPERSEND_WHATSAPP_ENDPOINT`: SuperSend WhatsApp endpoint or your proxy endpoint.
- `SUPERSEND_PUSH_ENDPOINT`: SuperSend push endpoint or your proxy endpoint.
- `WHATSAPP_PROVIDER`: `cloud` for official Meta WhatsApp Cloud API, or `twilio`.
- `WHATSAPP_CLOUD_ACCESS_TOKEN`: Meta WhatsApp Cloud API token.
- `WHATSAPP_CLOUD_PHONE_NUMBER_ID`: Meta phone number ID used in the Graph `/messages` endpoint.
- `WHATSAPP_CLOUD_WABA_ID`: WhatsApp Business Account ID, useful for template management.
- `WHATSAPP_CLOUD_TEMPLATE_NAME`: approved emergency template name.
- `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_WHATSAPP_FROM`: Twilio WhatsApp credentials if using Twilio.
- `TWILIO_CONTENT_SID`: optional Twilio approved WhatsApp content template SID.
- `NGX_NTFY_TOPIC`: immediate push fallback topic for the guardian's ntfy app.

If SuperSend endpoints are empty, the backend returns dry-run notification
results. This is intentional until you provide the exact WhatsApp/push endpoint
shape from your SuperSend account.

SuperSend's public V2 OpenAPI currently exposes email/LinkedIn conversation
messaging, but not a direct WhatsApp or mobile push send endpoint. For real
public release, use one of these production paths:

- WhatsApp Business Cloud API, Twilio WhatsApp, or another verified WhatsApp provider.
- Firebase Cloud Messaging, OneSignal, or a custom guardian app for push.
- `ntfy` as a fast prototype push channel: install the ntfy app on the guardian
  phone and subscribe to the `NGX_NTFY_TOPIC` value.

## Automatic WhatsApp setup

### Option A: official Meta WhatsApp Cloud API

Create a Meta developer app with WhatsApp enabled, add a WhatsApp Business
phone number, then copy these values into `.env`:

```env
WHATSAPP_PROVIDER=cloud
WHATSAPP_GRAPH_VERSION=v23.0
WHATSAPP_CLOUD_ACCESS_TOKEN=your_meta_access_token
WHATSAPP_CLOUD_PHONE_NUMBER_ID=your_phone_number_id
WHATSAPP_CLOUD_WABA_ID=your_whatsapp_business_account_id
WHATSAPP_CLOUD_TEMPLATE_NAME=neuroguardian_emergency_alert
WHATSAPP_CLOUD_TEMPLATE_LANGUAGE=en_US
```

For automatic guardian alerts, create and approve a utility template named
`neuroguardian_emergency_alert` with four body variables:

```text
NeuroGuardian X emergency alert. Reason is {{1}} for this alert. Patient location link is {{2}} for navigation. Nearby medical facilities are {{3}} for emergency routing. Latest vitals are {{4}} from the watch. Please respond immediately.
```

Without an approved template, WhatsApp text messages usually work only inside a
valid 24-hour customer-service window. Keep `WHATSAPP_CLOUD_ALLOW_TEXT=false`
for production.

### Option B: Twilio WhatsApp

Use Twilio Sandbox for testing or an approved WhatsApp sender for production.
Copy these values into `.env`:

```env
WHATSAPP_PROVIDER=twilio
TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=your_twilio_auth_token
TWILIO_WHATSAPP_FROM=+14155238886
TWILIO_CONTENT_SID=HXxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

If `TWILIO_CONTENT_SID` is empty, the backend sends a plain WhatsApp body. For
production-initiated alerts, use an approved Twilio content template.

## Endpoints

- `GET /health`: confirms server and key presence.
- `POST /medical-facilities/nearby`: returns up to three nearby hospitals.
- `POST /emergency/alert`: sends WhatsApp and push alerts when configured.

The alert includes the patient's exact Google Maps link, vitals snapshot, and
the medical facility list.
