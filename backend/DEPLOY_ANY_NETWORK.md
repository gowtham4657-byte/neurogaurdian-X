# Run NeuroGuardian X SOS On Any Network

The phone can only send automatic WhatsApp/push SOS when it can reach the emergency backend. A laptop IP like `http://192.168.x.x:8080` works only on the same Wi-Fi. For real use, host this backend on a public HTTPS service.

## Recommended setup

Use a small cloud web service:

- Render, Railway, Fly.io, Azure App Service, AWS, or Google Cloud Run.
- Runtime: Python 3.12.
- Start command: `uvicorn emergency_server:app --host 0.0.0.0 --port $PORT`
- Health check path: `/health`

## Files added for deployment

- `Dockerfile` for Docker/cloud container hosting.
- `Procfile` for Procfile-based hosts.
- `railway.json` for Railway.
- `../render.yaml` for Render.
- `.dockerignore` so `.env` and logs are not uploaded into the image.

## Environment variables to set in the cloud dashboard

Copy the values from local `.env`, but do not upload the `.env` file itself.

Required:

- `NGX_DEVICE_TOKEN`
- `GOOGLE_MAPS_API_KEY`
- `WHATSAPP_PROVIDER=cloud`
- `WHATSAPP_GRAPH_VERSION=v23.0`
- `WHATSAPP_CLOUD_ACCESS_TOKEN`
- `WHATSAPP_CLOUD_PHONE_NUMBER_ID`
- `WHATSAPP_CLOUD_WABA_ID`
- `WHATSAPP_CLOUD_TEMPLATE_NAME=neuroguardian_emergency_alert`
- `WHATSAPP_CLOUD_TEMPLATE_LANGUAGE=en_US`

Optional backup push:

- `NTFY_BASE_URL=https://ntfy.sh`
- `NGX_NTFY_TOPIC`

## After deployment

Your cloud service will give a public URL like:

`https://neuroguardian-x-emergency-backend.example.com`

Test it from any browser:

`https://YOUR_BACKEND_URL/health`

Then point the Android app to it:

```powershell
cd "C:\Users\hp\Downloads\neuro gardian x\neuroguardian_app"
.\scripts\set_phone_backend.ps1 -BackendUrl "https://YOUR_BACKEND_URL"
```

After this, SOS can work from mobile data or any Wi-Fi, as long as the phone has internet and the backend is online.

## Important production note

Temporary Meta WhatsApp tokens expire. For a real release, create a permanent Meta System User token with the required WhatsApp permissions, and rotate it safely if exposed.
