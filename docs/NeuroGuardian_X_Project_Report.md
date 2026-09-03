# NeuroGuardian X Project Report

## 1. Project Overview

NeuroGuardian X is a wearable-connected safety and health risk-detection system.
It combines an ESP32-S3 wrist-worn device, a Flutter mobile app, and an
emergency backend. The goal is to detect falls, no-movement conditions, sudden
heart-rate changes, stress signals, body-temperature changes, and other watch
health patterns, then alert guardians faster with GPS location and nearby
medical facility information.

The project is designed as a support and emergency-routing tool, not a medical
diagnosis system. For public use, it must still be validated with real sensors,
real fall tests, emergency-contact testing, and legal/medical review.

## 2. Main Components

### Mobile App

- Built with Flutter.
- Installed APK supports Android phone testing.
- Connects to ESP32-S3 wearable through Bluetooth Low Energy.
- Shows live vitals, risk detection, history, care suggestions, device status,
  and SOS controls.
- Stores guardian/emergency settings locally on the phone.

### ESP32-S3 Wearable Firmware

- Flashed to ESP32-S3 board.
- Advertises as `NeuroGuardianX`.
- Streams JSON sensor packets over BLE.
- Accepts commands from app such as `BUZZER_ON` and `BUZZER_OFF`.
- Supports fall/no-movement state, buzzer, vibration motor, battery input, GSR,
  ECG analog input, MPU6050 motion, optional MAX30102, and optional GPS hooks.

### Emergency Backend

- Built with FastAPI.
- Runs locally/server-side.
- Keeps secret keys out of the mobile app.
- Uses Google Places for top nearby medical facilities.
- Supports WhatsApp through Meta WhatsApp Cloud API or Twilio.
- Supports push fallback through ntfy.

## 3. System Architecture

```text
ESP32-S3 Watch
  -> BLE JSON packets
  -> Flutter Mobile App
  -> Local risk detection + fall timer
  -> Emergency backend
  -> Google Places hospital lookup
  -> WhatsApp / Push / SMS fallback
  -> Guardian and emergency responder awareness
```

## 4. Input Data

### Wearable Sensor Inputs

| Input | Source | Purpose |
| --- | --- | --- |
| Heart rate | MAX30102/MAX86141 or compatible PPG sensor | Cardiac load, sudden HR drop, stress support |
| SpO2 | Optical PPG sensor | Oxygen safety risk detection |
| HRV | Beat-to-beat interval calculation | Stress and cardiac risk support |
| GSR/EDA | Skin conductance sensor | Stress response detection |
| ECG amplitude | AD8232 or ECG analog module | ECG-ready cardiac pattern support |
| Body temperature | MAX30205/MAX30208 or optical temp fallback | Fever/heat strain detection |
| Acceleration/gyro | MPU6050/IMU | Fall detection and movement recovery |
| GPS latitude/longitude | Watch GPS module or phone GPS fallback | SOS location link |
| GPS accuracy | GPS module/phone GPS | Shows location confidence |
| Battery percentage | Battery voltage divider | Low battery warning |
| Manual SOS button | Watch button | Manual emergency/test trigger |

### User Inputs

| Input | Entered By | Purpose |
| --- | --- | --- |
| Guardian WhatsApp number | Wearable owner | Automatic/manual guardian alert |
| Ambulance/hospital contact | Wearable owner | Emergency fallback contact |
| Push target/topic | User/admin | Guardian push notification |
| Backend URL | User/admin | Connects app to emergency backend |
| Backend device token | User/admin | Authenticates app-to-backend alert |
| Prescriptions | User/doctor | Stores doctor-suggested medicines locally |

### Backend Configuration Inputs

| Input | Stored In | Purpose |
| --- | --- | --- |
| Google Maps API key | Backend `.env` | Nearby hospital lookup |
| Meta WhatsApp access token | Backend `.env` | Automatic WhatsApp alerts |
| WhatsApp phone number ID | Backend `.env` | Meta Cloud API sender ID |
| WhatsApp Business Account ID | Backend `.env` | Template management |
| WhatsApp template name | Backend `.env` | Approved emergency message |
| ntfy topic | Backend `.env` | Push fallback notification |

### Dataset Inputs for Future AI Model

| Dataset | Planned Use |
| --- | --- |
| MIT-BIH Arrhythmia Database | ECG rhythm and arrhythmia research |
| Sudden Cardiac Death Holter Database | Serious cardiac-risk ECG research |
| Wearable Device Dataset | Stress/exercise model from BVP, EDA, temperature, motion |
| Wearable Exam Stress Dataset | Real-world stress trend validation |

## 5. BLE Data Packet

The ESP32-S3 sends a JSON packet like this:

```json
{
  "event": "none",
  "ts": 12,
  "hr": 72,
  "sp": 98,
  "hrv": 45,
  "gsr": 30,
  "tp": 36.7,
  "st": 34,
  "ac": 0,
  "activity": "Resting",
  "flags": 2,
  "mv": 1,
  "bt": 87,
  "ecg": 0.64,
  "lat": 0,
  "lon": 0,
  "gps": 0
}
```

Emergency examples:

```json
{"event":"fall_detected","mv":0}
{"event":"critical_fall","hr":58,"mv":0}
{"event":"no_movement","mv":0}
```

## 6. Processing Logic

### Fall Detection

1. ESP32 detects fall impact using IMU.
2. App receives `fall_detected`.
3. App starts 30-second countdown.
4. Phone gives haptic feedback during countdown.
5. App sends `BUZZER_ON` to wearable.
6. If movement returns, timer stops and app sends `BUZZER_OFF`.
7. If no movement continues for 30 seconds, auto SOS triggers.
8. If fall plus sudden HR drop is detected, SOS triggers immediately.

### SOS Logic

1. App gets watch GPS if available.
2. If watch GPS is unavailable, app uses phone GPS fallback.
3. Backend fetches top 3 nearby hospitals using Google Places.
4. Alert message includes:
   - Emergency reason
   - Google Maps location link
   - Nearby medical facility list
   - Latest vitals
   - Accuracy estimate
5. Backend sends WhatsApp/push if configured.
6. App falls back to WhatsApp composer or SMS composer when needed.

### Risk Detection

Current app uses rule-based risk detection:

- High/low heart rate
- Low SpO2
- High stress/GSR
- Fever/high body temperature
- Fall/no-movement emergency
- Watch signal quality
- Battery low warning

Future AI model integration should replace or support `riskScoresProvider`,
while keeping rule-based fall/SOS logic as a safety fallback.

## 7. Output Data

### App Outputs

| Output | Where It Appears |
| --- | --- |
| Live vitals | Live dashboard |
| Health/risk score | Dashboard risk panel |
| AI risk detection label | Dashboard |
| Fall countdown timer | Dashboard and SOS tab |
| I AM OKAY button | Dashboard and SOS tab |
| Temperature meter | Dashboard |
| Detection database cards | Dashboard |
| Exercise/home-care suggestions | Care tab |
| Consult doctor warning | Care tab for serious criteria |
| Doctor prescription list | Care tab |
| Alert history | History tab |
| Device BLE status | Device tab |

### Wearable Outputs

| Output | Purpose |
| --- | --- |
| BLE vitals stream | Sends sensor data to app |
| BLE advertising name `NeuroGuardianX` | Allows app scan/connect |
| Vibration motor | Wrist alert during emergency countdown |
| Buzzer | Emergency feedback |
| LED | Connection/status feedback |

### Backend Outputs

| Output | Destination |
| --- | --- |
| Nearby hospital list | App/alert payload |
| WhatsApp alert | Guardian number entered by owner |
| Push alert | ntfy or configured push provider |
| API response | App SOS status |

### Emergency Alert Message Output

The alert includes:

- `SOS from NeuroGuardian X`
- Reason: no movement, critical fall, manual SOS, etc.
- Vitals: HR, SpO2, stress, GSR, ECG, temperature, battery, movement
- Google Maps exact-location link
- Top 3 nearby medical facilities
- Location accuracy estimate

## 8. Current Implementation Status

### Completed

- Flutter app created and installed on Android phone.
- ESP32-S3 old flash erased.
- New ESP32-S3 firmware uploaded successfully.
- BLE service/characteristic protocol implemented.
- Fall timer and movement cancellation implemented.
- Critical fall immediate SOS logic implemented.
- Buzzer/vibration command loop implemented.
- Google Places backend hospital lookup working with new API key.
- ntfy push fallback tested successfully.
- Meta WhatsApp Cloud API credentials saved and verified.
- WhatsApp emergency template created in Meta.
- Template status is currently `PENDING`.

### Pending

- Meta must approve the WhatsApp template before automatic WhatsApp alerts work.
- Real sensor modules must be wired and calibrated.
- MAX30102 and GPS firmware flags/libraries must be enabled after wiring.
- Google API key should be restricted safely before public release.
- Temporary Meta access token should be replaced with a permanent system-user token.
- Public release needs privacy, medical, and emergency-service compliance review.

## 9. Risks and Limitations

- The app can miss real emergencies if sensors are loose, offline, or badly
  calibrated.
- The app can create false alerts from sudden movement or sensor noise.
- Wrist ECG/SpO2 can be unreliable without strong skin contact.
- GPS may fail indoors.
- Direct ambulance dispatch needs verified emergency service integration, not
  only a Google Maps hospital list.
- WhatsApp automatic messages need approved provider templates.
- This system should not claim diagnosis, heart attack confirmation, or medical
  replacement behavior.

## 10. Recommended Next Steps

1. Wait for Meta template approval.
2. Test WhatsApp sending after approval.
3. Open app and scan for `NeuroGuardianX`.
4. Test fall, no movement, and movement recovery with ESP32.
5. Wire final sensors and enable firmware flags.
6. Collect real prototype data for calibration.
7. Train and validate AI models using PhysioNet plus your own watch data.
8. Prepare compliance, privacy policy, consent flow, and field-testing protocol
   before society/public release.

## 11. Important Project Paths

- Flutter app: `C:\Users\hp\Downloads\neuro gardian x\neuroguardian_app`
- APK: `C:\Users\hp\Downloads\neuro gardian x\neuroguardian_app\build\app\outputs\flutter-apk\app-debug.apk`
- ESP32 firmware: `C:\Users\hp\Downloads\neuro gardian x\neuroguardian_app\firmware\esp32_neuroguardian_ble\esp32_neuroguardian_ble.ino`
- Backend server: `C:\Users\hp\Downloads\neuro gardian x\neuroguardian_app\backend\emergency_server.py`
- Backend secrets: `C:\Users\hp\Downloads\neuro gardian x\neuroguardian_app\backend\.env`
- Model plan: `C:\Users\hp\Downloads\neuro gardian x\neuroguardian_app\docs\physionet_model_training_plan.md`
