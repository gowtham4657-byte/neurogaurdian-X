# Security and private configuration

Never commit production API keys, access tokens, backend `.env` files, signing
keys, guardian phone numbers, patient locations, personal health logs or database
exports. Use `backend/.env.example` as a names-only configuration template and
configure production values privately on the server.

Rotate any credentials previously pasted into chat or otherwise exposed. Removing
a secret from a new commit does not revoke it or erase earlier Git history.

Provider secrets belong on the backend. A token embedded in a mobile application
can be extracted; it is not a substitute for per-user/device authentication.
Treat push topics and device credentials as private. Review push-provider access
controls before transmitting health or location information.

Do not report security issues with real tokens, contact details or health records
in public GitHub issues. Use a private maintainer channel or GitHub private
vulnerability reporting if the repository owner has enabled it.

This prototype has not undergone an independent security or medical-device audit.
