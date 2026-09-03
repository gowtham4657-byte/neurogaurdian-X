# NeuroGuardian X wearable safety companion

Location: `C:\Users\hp\Downloads\neuro gardian x\neuroguardian_app`

## What's included
- Flutter app shell with six tabs: Live, Analytics, History, Care, Device, SOS.
- ESP32 BLE wearable connection screen that scans, lists devices, connects, and subscribes to NeuroGuardian packets.
- Real-wearable mode by default. Developer demo tools are hidden unless the app is run with `--dart-define=NGX_DEMO_MODE=true`.
- Riverpod state for live metrics and placeholder risk scores.
- Local history store (Hive) with a Guardian Alert Feed and raw sample history on the History tab.
- SOS screen that texts a guardian or hospital/ambulance contact with watch GPS when available, phone GPS fallback, vitals, and a nearby-hospital Google Maps search link.
- Backend-safe emergency notification hook for WhatsApp and push redundancy. The phone sends one alert payload to your backend; Google Maps, WhatsApp, Twilio, SuperSend, and push secrets stay on the server.
- First-run safety consent so users understand this is risk detection support, not medical diagnosis.
- Emergency contacts are saved locally with Hive and reused for manual and automatic SOS.
- Each wearable owner enters their own guardian WhatsApp number in the SOS tab; the backend uses that user-saved number during automatic WhatsApp alerts.
- Local safety alerts are created for falls, fall-timer events, auto SOS, high/low heart rate, low SpO2, fever-range temperature, high stress, and low wearable battery.
- Local detection databases for heart attack risk, oxygen safety, stress response, burnout, thermal safety, fall/no-movement, and watch signal health.
- Watch signals for MAX30102 heart rate/SpO2, HRV, GSR stress, AD8232 ECG amplitude, MPU6050 motion/fall state, body temperature, and GPS patient location.
- Fall SOS monitor: a fall signal starts a 30-second unconscious-patient timer; later movement from the watch stops it, otherwise hospital/ambulance SOS opens with patient GPS after 30 seconds.
- Critical fall monitor: fall plus sudden heart-rate drop opens an immediate hospital/ambulance SOS message with patient GPS.
- BLE emergency command loop: the app sends `BUZZER_ON` to the wristband during the countdown/SOS and `BUZZER_OFF` when the user taps `I AM OKAY`.
- Care tab: minor criteria show exercise/home-care suggestions; serious criteria show consult doctor/emergency guidance. Medicine entries are only for doctor-prescribed prescriptions and are saved locally.
- Care tab now includes sleep and recovery logging with a local sleep score, quality tracking, and sleep tips.
- Polished public-facing UI with a protection cockpit, trust cards, safety notices, and stronger mobile-friendly components.

## Public-use safety notes
- NeuroGuardian X should be presented as a monitoring and risk-detection support tool, not as a diagnosis engine or a replacement for professional care.
- Most phones open an SMS composer for confirmation; silent automatic emergency SMS and true nearest-hospital dispatch require native platform work, a verified hospital/ambulance directory or backend, explicit permissions, testing, and local legal review.
- Before any society/community rollout, test fall detection, no-movement cancellation, contact numbers, GPS permissions, battery behavior, BLE reconnection, and false-alert handling with real devices.
- If symptoms are serious, users should contact a doctor, guardian, hospital, or ambulance instead of relying on home remedies or exercise suggestions.

## How to run
1) Open the app-style preview:
```
cd "C:\Users\hp\Downloads\neuro gardian x\neuroguardian_app"
.\run_neuroguardian_x_app.bat
```
2) Or run from Flutter:
```
cd "C:\Users\hp\Downloads\neuro gardian x\neuroguardian_app"
..\flutter_sdk_backup\bin\flutter.bat run -d web-server --web-hostname 127.0.0.1 --web-port 8765
```
3) Open Device and scan for an ESP32 named `NeuroGuardianX`.
4) For developer-only simulator controls:
```
..\flutter_sdk_backup\bin\flutter.bat run --dart-define=NGX_DEMO_MODE=true
```

## Build outputs
- Installable web/PWA output: `build\web`
- Android debug APK output: `build\app\outputs\flutter-apk\app-debug.apk`
- For Play Store or public APK distribution, replace debug signing with a private release keystore in `android\app\build.gradle.kts`.

## Hooking to ESP32
- Production BLE service UUID: `6e670001-b5a3-f393-e0a9-e50e24dcca9e`
- Production vitals notify UUID: `6e670002-b5a3-f393-e0a9-e50e24dcca9e`
- Production command write UUID: `6e670003-b5a3-f393-e0a9-e50e24dcca9e`
- Legacy BLE service UUID is still supported: `0000ffe0-0000-1000-8000-00805f9b34fb`
- Starter firmware sketch: `firmware\esp32_neuroguardian_ble\esp32_neuroguardian_ble.ino`
- Production JSON packet: `{"event":"none","hr":72,"sp":98,"hrv":45,"gsr":30,"tp":36.7,"st":34,"ac":0,"activity":"Resting","flags":2,"mv":1,"bt":87,"ecg":0.64,"lat":0,"lon":0,"gps":0}`
- Event-only emergency packet also works: `{"event":"fall_detected","mv":0}`.
- Critical emergency packet: `{"event":"critical_fall","hr":58,"mv":0}`.
- Commands accepted by firmware: `BUZZER_ON`, `BUZZER_OFF`, `BUZZ`, `BUZZER_PULSE`, `LED_ON`, `LED_OFF`.
- Preferred binary packet: `0x4E`, `0x47`, `uint8 version`, `uint32 ts`, `uint8 hr`, `uint8 spo2`, `uint8 hrv`, `uint8 gsr`, `uint8 stress`, `int16 temp_c_x100`, `uint8 activity`, `uint8 flags`, `int16 ecg_mv_x1000`, optional `int32 latE7`, `int32 lonE7`, `uint16 gps_accuracy_x10`.
- Easy CSV packet: `NGX,ts,hr,spo2,hrv,gsr,stress,tempC,activity,flags,ecgMv,lat,lon,gpsAccuracyM`
- Activity codes: `0 Resting`, `1 Walking`, `2 Running`, `3 Fall detected`, `4 No movement`.
- Flags: bit `0x01` means fall detected; bit `0x02` means movement detected. A fall starts the 30-second timer. If movement returns before 30 seconds, the timer stops. If no movement continues for 30 seconds, the patient may be unconscious, so hospital/ambulance SOS opens with watch GPS when available, vitals, and a nearby-hospital map link. If heart rate drops by 20 bpm or more after a fall, hospital/ambulance SOS opens immediately with watch GPS when available.
- BLE support is meant for Android/iOS builds. The local web preview may not support real BLE on every browser/device.

## Emergency backend
- Backend folder: `backend`
- Local run guide: `backend\README.md`
- Server entrypoint: `backend\emergency_server.py`
- Secret template: `backend\.env.example`
- App SOS settings should use the backend base URL and device token. Do not put Google Maps or SuperSend production keys directly in the mobile app.
- Automatic WhatsApp is supported by the backend through official Meta WhatsApp Cloud API or Twilio WhatsApp. Use an approved emergency message template for production-initiated alerts.

## PhysioNet model roadmap
- Dataset/model plan: `docs\physionet_model_training_plan.md`
- MIT-BIH and SDDB are for ECG research/training.
- Wearable Device Dataset and Wearable Exam Stress Dataset are for stress/exercise detection patterns.
- The current app remains rule-based until a trained model is validated on real NeuroGuardian watch data.

## Next steps
- Flash the ESP32 sketch, then enable/install the exact sensor libraries for MAX30102/MAX86141, MAX30208, TinyGPSPlus, and any final ECG/GSR modules selected for the watch PCB.
- Replace `riskScoresProvider` with your AI endpoint or on-device model.
- Add authenticated cloud backup only if privacy, consent, and security requirements are ready.
- Run field validation with multiple users and compare watch alerts against real-world outcomes before public launch.
