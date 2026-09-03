# NeuroGuardian X Wrist Watch Sensor Layout

## Physical placement
- Back/skin side: MAX30102 optical window for heart rate and SpO2, plus MAX30205 body-temperature contact pad.
- Case center: BMI270 or MPU6050 IMU for fall impact, orientation, and no-movement detection.
- Strap inside: two gold GSR electrodes touching skin.
- Side/top bezel: ECG finger-touch pad; AD8232 reads between the wrist/back reference and finger pad.
- Top PCB edge: ESP32-C3 BLE antenna, kept away from battery, copper fill, and metal enclosure.
- Inside case: LiPo battery, MCP73831/TP4056 charger, power switch, vibration motor/buzzer.

## Recommended electronics
| Function | Part | Interface |
|---|---|---|
| BLE watch controller | ESP32-C3 or ESP32 | BLE GATT to Flutter app |
| Heart rate + SpO2 | MAX30102 | I2C |
| Fall/no movement | BMI270 preferred, MPU6050 prototype | I2C |
| Body temperature | MAX30205 preferred | I2C |
| Stress/GSR | GSR divider/electrodes | ADC |
| ECG touch reading | AD8232 | ADC + leads-off pins |
| GPS | Watch GPS module preferred for patient location; phone GPS fallback | UART |
| Power | 3.7V LiPo + charger + 3.3V regulator | Power |

## SOS flow
1. Watch detects fall impact using IMU.
2. App starts 30-second timer.
3. If watch reports movement after the fall, timer stops.
4. If no movement continues for 30 seconds, app opens hospital/ambulance SOS with watch GPS when available, vitals, and nearby-hospital map link.

## Prototype note
Use modules first. For a real wristwatch, build a custom PCB because breakout modules are too thick and consume more space/power.
