# NeuroGuardian X ESP32-S3 Firmware

> Development prototype. The GPIO table below is for generic DevKit defaults,
> not a verified XIAO ESP32-S3 wiring plan. The safety behaviour describes intent;
> known sampling and timer-cancellation defects remain in the archived study.
> See [current status](../../docs/CURRENT_STATUS.md) before hardware testing.
> Sensor fields do not imply completed or medically validated measurements, and
> an SOS flow is not verified hospital/ambulance dispatch.

This sketch turns an ESP32-S3 board into a NeuroGuardian X wearable. It advertises
as `NeuroGuardianX`, streams vitals over BLE, receives app commands, and reports
fall/no-movement state for the 30-second SOS timer.

## Hardware Pinout

| Module | Purpose | ESP32-S3 pin |
| --- | --- | --- |
| MPU6050 | Fall and movement detection | SDA GPIO8, SCL GPIO9 |
| GSR sensor | Stress / skin response | GPIO4 analog |
| AD8232 ECG | ECG amplitude input | GPIO6 analog |
| Battery divider | LiPo percentage | GPIO1 analog, 100k/100k divider |
| SOS button | Manual fall/SOS test button | GPIO7 to GND |
| Vibration motor | Haptic alert | GPIO5 through transistor + diode |
| Buzzer | Optional audible alert | GPIO26 |
| Status LED | BLE connection indicator | GPIO2 |
| GPS module | Optional watch GPS | RX GPIO16, TX GPIO17 |

## Stress Detection

The wearable now reports stress as a pattern score, not a single raw value.

- GSR/skin response is the strongest signal.
- HRV uses RMSSD-style beat-to-beat timing when MAX30102 is enabled.
- Heart-rate rise adds stress load, but active movement reduces false alerts.
- Body temperature adds a smaller heat-strain load when a valid sensor is present.
- Walking/running activity caps the stress score so exercise is not treated as stress too quickly.

## BLE Protocol

- Device name: `NeuroGuardianX`
- Service UUID: `6e670001-b5a3-f393-e0a9-e50e24dcca9e`
- Vitals notify UUID: `6e670002-b5a3-f393-e0a9-e50e24dcca9e`
- Command write UUID: `6e670003-b5a3-f393-e0a9-e50e24dcca9e`

The vitals characteristic sends JSON every second:

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

Commands accepted from the app:

- `BUZZER_ON` - keep the wearable motor/buzzer active.
- `BUZZER_OFF` - stop the wearable motor/buzzer.
- `BUZZ` / `BUZZER_PULSE` - pulse the wearable motor/buzzer.
- `LED_ON` - turn the status LED on.
- `LED_OFF` - turn the status LED off.

## Safety Behavior

- A fall impact starts the app's 30-second SOS countdown.
- Movement after the fall stops the countdown.
- No movement for 30 seconds triggers the app's ambulance/hospital SOS flow.
- A sudden heart-rate drop after fall triggers SOS immediately.
- Emergency event-only packets such as `{"event":"fall_detected","mv":0}` and
  `{"event":"critical_fall","hr":58,"mv":0}` are understood by the app.

## Flashing

```powershell
.\upload_esp32_firmware.bat COM3
```

Use the COM port shown for your ESP32. The default board is
`esp32:esp32:esp32s3`.

## Real Sensor Status

The firmware default is real mode (`USE_SIMULATED_SENSORS 0`). MPU6050, GSR,
ECG, battery, button, buzzer, LED, optional MAX30102, and optional TinyGPSPlus
GPS paths are wired in. Body temperature and HRV still need the exact final
sensor/library selection and calibration for your watch PCB.

## NeuroTwin Packet V2

The firmware now sends packet version `2` with raw motion and quality fields for
the real-user NeuroTwin screen:

```json
{
  "v": 2,
  "e": "n",
  "hr": 72,
  "sp": 98,
  "hrv": 45,
  "gs": 30,
  "tp": 36.7,
  "st": 34,
  "ac": 0,
  "fl": 2,
  "mv": 1,
  "bt": 87,
  "eg": 0.64,
  "la": 0,
  "lo": 0,
  "gp": 0,
  "ax": 0.01,
  "ay": 0.02,
  "az": 0.98,
  "gx": 0.1,
  "gy": 0.2,
  "gz": 0.1,
  "pr": 1008.6,
  "al": 760,
  "pq": 0.9,
  "eq": 0.86,
  "gq": 0.82,
  "tq": 0.78,
  "ct": 1
}
```

Short field names keep BLE packets small. The app still supports older packet
formats. `e` values are `n` for normal, `f` for fall, and `c` for critical fall.
Quality values are 0-1, where higher means more trustworthy signal contact.
