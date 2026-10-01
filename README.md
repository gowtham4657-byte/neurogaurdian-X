# NeuroGuardian X

Flutter companion app, ESP32-S3 BLE firmware, and a Python emergency-notification
backend for a wearable safety research prototype.

**Development prototype: not clinically validated, not a diagnostic device, and
not an ambulance dispatch service. Do not rely on it as the sole emergency channel.**

## Start here

- [Current features, known issues and remaining work](docs/CURRENT_STATUS.md)
- [ESP32-S3 firmware and packet format](firmware/esp32_neuroguardian_ble/README.md)
- [Backend setup](backend/README.md)
- [Public-network deployment](backend/DEPLOY_ANY_NETWORK.md)
- [Security and private configuration](SECURITY.md)
- [Research archive](research/journal_revision_2026-09-17/REPOSITORY_NOTES.md)
- [Dataset research roadmap](docs/physionet_model_training_plan.md)

Older reports and wiring drawings in `docs/` are historical. The current status
and actual board/sensor specifications take precedence over earlier design claims.

## Components

| Component | Technology | Role |
| --- | --- | --- |
| Mobile interface | Flutter / Dart | Live measurements, NeuroTwin, history, care, device and SOS screens |
| State and storage | Riverpod / Hive | Local application state, samples and owner settings |
| Wearable | Arduino C++ / ESP32-S3 | Sensor interfaces, BLE packets and alert commands |
| Server | Python / FastAPI | Authenticated alert endpoint and provider integrations |
| External services | Google Places, configured WhatsApp and push providers | Facility information and guardian notification requests |
| Research | Python, native C++, Flutter tests | Synthetic software-in-the-loop evaluations |

NeuroTwin uses statistical baselines and rule-based scores, not a trained clinical
AI model. Quality values and scores are heuristics, not calibrated probabilities.
Available fields depend on actual sensors and firmware configuration.

## Run the application

Install a compatible Flutter SDK and Android SDK, then from the repository root:

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```

The locally verified SDK was Flutter 3.19.5 / Dart 3.3.3. Dependency constraints
are in `pubspec.yaml`; resolved versions are in `pubspec.lock`.

For a UI-only browser preview:

```sh
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8765
```

Real BLE, permissions and background behaviour must be tested on the target phone;
a browser preview is not equivalent to a wearable-connected Android build.
Developer simulations are opt-in with `--dart-define=NGX_DEMO_MODE=true`.

Build a development APK with `flutter build apk --debug`. Release signing,
privacy review and physical-device validation are separate tasks. Do not publish
signing keys or treat a debug APK as a public-release product.

## Backend configuration

Follow `backend/README.md`. Copy `backend/.env.example` to a private `.env` file,
set required server credentials, then install `backend/requirements.txt` and run:

```sh
uvicorn emergency_server:app --host 0.0.0.0 --port 8080
```

Run that command from `backend/`. The health route is `/health`. `render.yaml`
describes the Render service. Use an HTTPS server URL for remote phone access.
Health-check success does not verify WhatsApp or push delivery.

The app supports `NGX_BACKEND_URL` configuration and per-owner guardian settings.
Keep provider credentials on the server; see `SECURITY.md` for the limitations of
mobile device tokens. Configure provider templates, permissions and guardian
consent before controlled notification testing.

## Wearable connection

- BLE name: `NeuroGuardianX`
- Service: `6e670001-b5a3-f393-e0a9-e50e24dcca9e`
- Notify: `6e670002-b5a3-f393-e0a9-e50e24dcca9e`
- Command: `6e670003-b5a3-f393-e0a9-e50e24dcca9e`

Packet-v2 fields support raw motion, quality/contact information, vitals and event
flags. The intended flow starts a 30-second countdown after a suspected fall and
allows cancellation. Known sampling/cancellation defects are documented in
`docs/CURRENT_STATUS.md`; uploading this source does not fix those defects.

The sketch uses generic ESP32-S3 DevKit GPIOs, not a verified XIAO wiring map.
Read the firmware guide and check the exact hardware before connecting or flashing.
Optional optical/GPS libraries are disabled by default; temperature and pressure
support is incomplete. Missing sensors must not be interpreted as normal health.

## Notification meaning

A guardian must be configured by the wearable owner. A server/provider acceptance
response is not proof of delivery or acknowledgment. Google Places returns nearby
facility information, not a dispatch relationship. SMS may require user confirmation.
Do not send test emergencies to hospitals or emergency numbers.

## Research status

The included journal revision reports synthetic software tests, not patient trials.
No PhysioNet dataset was used for training or evaluation in that study. The
experimental recovery guard is not installed in the wearable. Author placeholders,
journal-specific formatting and reproducibility improvements remain before submission.
No IEEE acceptance, certified plagiarism score or clinical accuracy is claimed.
