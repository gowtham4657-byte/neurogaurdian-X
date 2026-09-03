// NeuroGuardian X ESP32 BLE firmware
// Board: ESP32 / ESP32-S3 using Arduino IDE or Arduino extension.
// App BLE service: 6e670001-b5a3-f393-e0a9-e50e24dcca9e
// App BLE notify characteristic: 6e670002-b5a3-f393-e0a9-e50e24dcca9e
// App BLE command characteristic: 6e670003-b5a3-f393-e0a9-e50e24dcca9e
//
// Production default does not fake vitals. Enable USE_SIMULATED_SENSORS only
// for bench testing when sensors are not connected.

#include <Arduino.h>
#include <BLE2902.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <Wire.h>
#include <math.h>

static const char *DEVICE_NAME = "NeuroGuardianX";
static const char *SERVICE_UUID = "6e670001-b5a3-f393-e0a9-e50e24dcca9e";
static const char *METRICS_UUID = "6e670002-b5a3-f393-e0a9-e50e24dcca9e";
static const char *COMMAND_UUID = "6e670003-b5a3-f393-e0a9-e50e24dcca9e";

// 0 = real wearable mode. 1 = local bench simulator.
#define USE_SIMULATED_SENSORS 0
// Set to 1 after installing the SparkFun MAX3010x library and wiring MAX30102.
#define USE_MAX30102_SENSOR 0
// Set to 1 after installing TinyGPSPlus and wiring a GPS module to Serial1.
#define USE_TINYGPSPLUS_SENSOR 0

#if USE_MAX30102_SENSOR
#include "MAX30105.h"
#include "heartRate.h"
MAX30105 particleSensor;
bool max30102Ready = false;
const byte RATE_SIZE = 6;
byte rates[RATE_SIZE];
byte rateSpot = 0;
long lastBeat = 0;
int beatAvg = 0;
const byte HRV_SIZE = 10;
uint16_t beatIntervalsMs[HRV_SIZE];
byte beatIntervalSpot = 0;
byte beatIntervalCount = 0;
uint8_t hrvRmssdMs = 0;
float spo2Estimate = 98.0f;
long redSum = 0;
long irSum = 0;
long redMin = 999999;
long redMax = 0;
long irMin = 999999;
long irMax = 0;
int opticalSampleCount = 0;
#endif

#if USE_TINYGPSPLUS_SENSOR
#include <TinyGPSPlus.h>
TinyGPSPlus gps;
#endif

// ESP32-S3 DevKit defaults. Change these if your PCB wiring is different.
static const int I2C_SDA_PIN = 8;
static const int I2C_SCL_PIN = 9;
static const int GSR_PIN = 4;
static const int ECG_PIN = 6;
static const int BATTERY_PIN = 1;
static const int SOS_BUTTON_PIN = 7;
static const int BUZZER_PIN = 26;
static const int VIBRATION_PIN = 5;
static const int STATUS_LED_PIN = 2;
static const int GPS_RX_PIN = 16;
static const int GPS_TX_PIN = 17;
static const uint8_t MPU6050_ADDR = 0x68;

static const unsigned long NOTIFY_INTERVAL_MS = 1000;
static const unsigned long FALL_COUNTDOWN_MS = 30000;
static const float IMPACT_THRESHOLD_G = 2.6f;
static const float MOVEMENT_DELTA_G = 0.10f;
static const float RUNNING_DELTA_G = 0.35f;
static const int SUDDEN_HR_DROP_BPM = 22;

// Activity codes used by the Flutter app.
static const uint8_t ACTIVITY_RESTING = 0;
static const uint8_t ACTIVITY_WALKING = 1;
static const uint8_t ACTIVITY_RUNNING = 2;
static const uint8_t ACTIVITY_FALL = 3;
static const uint8_t ACTIVITY_NO_MOVEMENT = 4;

// Flags parsed by the app:
// bit 0 = fall detected
// bit 1 = movement detected
// Extra bits are for future firmware/app versions.
static const uint8_t FLAG_FALL = 0x01;
static const uint8_t FLAG_MOVEMENT = 0x02;
static const uint8_t FLAG_SOS_COUNTDOWN = 0x04;
static const uint8_t FLAG_CRITICAL = 0x08;
static const uint8_t FLAG_MANUAL_SOS = 0x10;

BLECharacteristic *metricsCharacteristic = nullptr;
bool deviceConnected = false;
unsigned long lastNotifyMs = 0;
unsigned long fallStartedMs = 0;
bool fallCountdownActive = false;
bool criticalNow = false;
bool mpuReady = false;
float lastAccelG = 1.0f;
uint8_t previousHeartRate = 0;
bool appAlertActive = false;
unsigned long commandPulseUntilMs = 0;

void setAlertOutput(bool on);
void refreshAlertOutput();
void pulseAlertOutput(unsigned long durationMs);

class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer *server) override {
    deviceConnected = true;
    digitalWrite(STATUS_LED_PIN, HIGH);
    Serial.println("Phone/app connected");
  }

  void onDisconnect(BLEServer *server) override {
    deviceConnected = false;
    digitalWrite(STATUS_LED_PIN, LOW);
    Serial.println("Phone/app disconnected - advertising again");
    server->startAdvertising();
  }
};

class CommandCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *characteristic) override {
    String command = String(characteristic->getValue().c_str());
    command.trim();
    command.toUpperCase();

    if (command == "BUZZ" || command == "BUZZER_PULSE") {
      pulseAlertOutput(650);
    } else if (command == "BUZZER_ON") {
      appAlertActive = true;
      commandPulseUntilMs = 0;
      refreshAlertOutput();
    } else if (command == "BUZZER_OFF") {
      appAlertActive = false;
      commandPulseUntilMs = 0;
      refreshAlertOutput();
    } else if (command == "LED_ON") {
      digitalWrite(STATUS_LED_PIN, HIGH);
    } else if (command == "LED_OFF") {
      digitalWrite(STATUS_LED_PIN, LOW);
    }
  }
};

void putU32(uint8_t *packet, int offset, uint32_t value) {
  packet[offset] = value & 0xff;
  packet[offset + 1] = (value >> 8) & 0xff;
  packet[offset + 2] = (value >> 16) & 0xff;
  packet[offset + 3] = (value >> 24) & 0xff;
}

void putI32(uint8_t *packet, int offset, int32_t value) {
  packet[offset] = value & 0xff;
  packet[offset + 1] = (value >> 8) & 0xff;
  packet[offset + 2] = (value >> 16) & 0xff;
  packet[offset + 3] = (value >> 24) & 0xff;
}

void putI16(uint8_t *packet, int offset, int16_t value) {
  packet[offset] = value & 0xff;
  packet[offset + 1] = (value >> 8) & 0xff;
}

void putU16(uint8_t *packet, int offset, uint16_t value) {
  packet[offset] = value & 0xff;
  packet[offset + 1] = (value >> 8) & 0xff;
}

void initMax30102() {
#if USE_MAX30102_SENSOR
  if (particleSensor.begin(Wire, I2C_SPEED_FAST)) {
    max30102Ready = true;
    particleSensor.setup(60, 4, 2, 100, 411, 4096);
    particleSensor.enableDIETEMPRDY();
    Serial.println("MAX30102 ready - HR, SpO2 and optical temp active.");
  } else {
    Serial.println("MAX30102 not found - HR/SpO2/temp stay unavailable.");
  }
#endif
}

uint8_t computeHrvRmssd() {
#if USE_MAX30102_SENSOR
  if (beatIntervalCount < 3) return 0;

  uint16_t ordered[HRV_SIZE];
  for (byte i = 0; i < beatIntervalCount; i++) {
    const byte idx =
        (beatIntervalSpot + HRV_SIZE - beatIntervalCount + i) % HRV_SIZE;
    ordered[i] = beatIntervalsMs[idx];
  }

  unsigned long sumSquares = 0;
  for (byte i = 1; i < beatIntervalCount; i++) {
    const long diff = (long)ordered[i] - (long)ordered[i - 1];
    sumSquares += (unsigned long)(diff * diff);
  }

  const float meanSquares = (float)sumSquares / (beatIntervalCount - 1);
  return constrain((int)sqrtf(meanSquares), 0, 200);
#else
  return 0;
#endif
}

void sampleMax30102() {
#if USE_MAX30102_SENSOR
  if (!max30102Ready) return;

  const long ir = particleSensor.getIR();
  const long red = particleSensor.getRed();
  if (ir > 50000 && checkForBeat(ir)) {
    const unsigned long now = millis();
    if (lastBeat > 0) {
      const unsigned long delta = now - lastBeat;
      const float bpm = 60.0f / (delta / 1000.0f);
      if (bpm > 30 && bpm < 220 && delta >= 300 && delta <= 2000) {
        rates[rateSpot++] = (byte)bpm;
        rateSpot %= RATE_SIZE;
        int total = 0;
        for (byte i = 0; i < RATE_SIZE; i++) total += rates[i];
        beatAvg = total / RATE_SIZE;
        beatIntervalsMs[beatIntervalSpot++] = (uint16_t)delta;
        beatIntervalSpot %= HRV_SIZE;
        if (beatIntervalCount < HRV_SIZE) beatIntervalCount++;
        hrvRmssdMs = computeHrvRmssd();
      }
    }
    lastBeat = now;
  }
  if (ir < 50000) {
    beatAvg = 0;
    beatIntervalCount = 0;
    beatIntervalSpot = 0;
    hrvRmssdMs = 0;
  }

  redSum += red;
  irSum += ir;
  opticalSampleCount++;
  if (red < redMin) redMin = red;
  if (red > redMax) redMax = red;
  if (ir < irMin) irMin = ir;
  if (ir > irMax) irMax = ir;
#endif
}

void sampleGps() {
#if USE_TINYGPSPLUS_SENSOR
  while (Serial1.available() > 0) {
    gps.encode(Serial1.read());
  }
#endif
}

void updateSpo2Window() {
#if USE_MAX30102_SENSOR
  if (!max30102Ready || opticalSampleCount <= 20 || beatAvg <= 0) {
    redSum = irSum = opticalSampleCount = 0;
    redMin = irMin = 999999;
    redMax = irMax = 0;
    return;
  }

  const float dcRed = (float)redSum / opticalSampleCount;
  const float dcIr = (float)irSum / opticalSampleCount;
  const float acRed = (float)(redMax - redMin);
  const float acIr = (float)(irMax - irMin);
  if (dcRed > 0 && dcIr > 0 && acIr > 0) {
    const float ratio = (acRed / dcRed) / (acIr / dcIr);
    const float estimated = 110.0f - 25.0f * ratio;
    if (estimated >= 70 && estimated <= 100) {
      spo2Estimate = spo2Estimate * 0.7f + estimated * 0.3f;
    }
  }
  redSum = irSum = opticalSampleCount = 0;
  redMin = irMin = 999999;
  redMax = irMax = 0;
#endif
}

uint8_t readHeartRate() {
#if USE_SIMULATED_SENSORS
  return constrain(76 + random(-8, 9), 45, 180);
#else
#if USE_MAX30102_SENSOR
  return max30102Ready ? constrain(beatAvg, 0, 220) : 0;
#else
  // Wire your selected optical heart sensor here.
  return 0;
#endif
#endif
}

uint8_t readSpo2() {
#if USE_SIMULATED_SENSORS
  return constrain(97 + random(-2, 3), 70, 100);
#else
#if USE_MAX30102_SENSOR
  updateSpo2Window();
  return max30102Ready && beatAvg > 0 ? constrain((int)spo2Estimate, 70, 100) : 0;
#else
  // Wire your selected SpO2 sensor here.
  return 0;
#endif
#endif
}

uint8_t readHrv() {
#if USE_SIMULATED_SENSORS
  return constrain(48 + random(-10, 11), 5, 120);
#else
#if USE_MAX30102_SENSOR
  return max30102Ready && beatAvg > 0 ? hrvRmssdMs : 0;
#else
  // Wire your selected optical heart sensor here and return RMSSD-style HRV.
  return 0;
#endif
#endif
}

uint8_t readGsrLevel() {
#if USE_SIMULATED_SENSORS
  return constrain(35 + random(-15, 16), 0, 100);
#else
  const int raw = analogRead(GSR_PIN);
  return constrain(map(raw, 0, 4095, 0, 100), 0, 100);
#endif
}

int16_t readEcgMvX1000() {
#if USE_SIMULATED_SENSORS
  const float ecgMv = 0.65f + (random(-15, 16) / 100.0f);
  return (int16_t)(ecgMv * 1000.0f);
#else
  const int raw = analogRead(ECG_PIN);
  const float volts = (raw / 4095.0f) * 3.3f;
  const float centeredMv = (volts - 1.65f) * 1000.0f;
  return (int16_t)constrain(centeredMv, -2000.0f, 2000.0f);
#endif
}

int16_t readBodyTempX100() {
#if USE_SIMULATED_SENSORS
  const float tempC = 36.7f + (random(-12, 13) / 100.0f);
  return (int16_t)(tempC * 100.0f);
#else
#if USE_MAX30102_SENSOR
  return max30102Ready ? (int16_t)(particleSensor.readTemperature() * 100.0f) : 0;
#else
  // Wire MAX30208/MAX30205 or another body-temperature sensor here.
  return 0;
#endif
#endif
}

void initMpu6050() {
  Wire.beginTransmission(MPU6050_ADDR);
  Wire.write(0x6B);
  Wire.write(0x00);
  if (Wire.endTransmission() != 0) {
    Serial.println("MPU6050 not found - motion/fall detection disabled.");
    mpuReady = false;
    return;
  }

  Wire.beginTransmission(MPU6050_ADDR);
  Wire.write(0x1C);
  Wire.write(0x18);  // +/-16g range: 2048 LSB/g.
  Wire.endTransmission();
  mpuReady = true;
  Serial.println("MPU6050 ready - fall detection active.");
}

float readAccelerationMagnitudeG() {
#if USE_SIMULATED_SENSORS
  // Normal idle movement around 1 g. Press SOS button to simulate fall.
  if (digitalRead(SOS_BUTTON_PIN) == LOW) return 3.2f;
  return 1.0f + (random(-4, 5) / 100.0f);
#else
  if (!mpuReady) return 1.0f;

  Wire.beginTransmission(MPU6050_ADDR);
  Wire.write(0x3B);
  if (Wire.endTransmission(false) != 0) return lastAccelG;
  if (Wire.requestFrom(MPU6050_ADDR, (uint8_t)6) != 6) return lastAccelG;

  const int16_t ax = (Wire.read() << 8) | Wire.read();
  const int16_t ay = (Wire.read() << 8) | Wire.read();
  const int16_t az = (Wire.read() << 8) | Wire.read();
  return sqrtf((float)ax * ax + (float)ay * ay + (float)az * az) / 2048.0f;
#endif
}

int32_t readGpsLatitudeE7() {
#if USE_SIMULATED_SENSORS
  // 0 means no watch GPS fix. The app will use phone GPS fallback.
  return 0;
#else
#if USE_TINYGPSPLUS_SENSOR
  return gps.location.isValid() ? (int32_t)(gps.location.lat() * 10000000.0) : 0;
#else
  // Wire TinyGPSPlus or your selected GNSS module here.
  return 0;
#endif
#endif
}

int32_t readGpsLongitudeE7() {
#if USE_SIMULATED_SENSORS
  return 0;
#else
#if USE_TINYGPSPLUS_SENSOR
  return gps.location.isValid() ? (int32_t)(gps.location.lng() * 10000000.0) : 0;
#else
  // Wire TinyGPSPlus or your selected GNSS module here.
  return 0;
#endif
#endif
}

uint16_t readGpsAccuracyX10() {
#if USE_SIMULATED_SENSORS
  return 0;
#else
#if USE_TINYGPSPLUS_SENSOR
  return gps.hdop.isValid() ? (uint16_t)(gps.hdop.hdop() * 10.0) : 0;
#else
  // Return estimated GPS accuracy in meters x10 if your module provides it.
  return 0;
#endif
#endif
}

int readBatteryPct() {
#if USE_SIMULATED_SENSORS
  return 86;
#else
  const int millivolts = analogReadMilliVolts(BATTERY_PIN) * 2;
  if (millivolts < 2800 || millivolts > 4600) return -1;
  return constrain((millivolts - 3300) * 100 / (4200 - 3300), 0, 100);
#endif
}

uint8_t computeStress(
    uint8_t gsr, uint8_t hrv, uint8_t heartRate, int16_t tempX100, uint8_t activity) {
  const bool hasHr = heartRate >= 30 && heartRate <= 220;
  const bool hasHrv = hrv > 0 && hrv <= 200;
  const float tempC = tempX100 / 100.0f;
  const bool hasTemp = tempC >= 30.0f && tempC <= 45.0f;
  const int hrvLoad = hasHrv ? constrain(100 - hrv, 0, 100) : 35;
  const int hrLoad = hasHr ? constrain((heartRate - 70) * 2, 0, 100) : 0;
  const int tempLoad = hasTemp ? constrain((int)((tempC - 36.8f) * 35.0f), 0, 100) : 0;
  int score = (gsr * 45 + hrvLoad * 25 + hrLoad * 20 + tempLoad * 10) / 100;

  // Motion filter: active movement can raise HR without psychological stress.
  if (activity == ACTIVITY_RUNNING) score = min(score, 58);
  if (activity == ACTIVITY_WALKING) score = min(score, 70);
  return constrain(score, 0, 100);
}

void setAlertOutput(bool on) {
  digitalWrite(BUZZER_PIN, on ? HIGH : LOW);
  digitalWrite(VIBRATION_PIN, on ? HIGH : LOW);
}

void refreshAlertOutput() {
  if (commandPulseUntilMs > 0 && millis() >= commandPulseUntilMs) {
    commandPulseUntilMs = 0;
  }
  const bool pulseActive = commandPulseUntilMs > 0;
  setAlertOutput(fallCountdownActive || appAlertActive || pulseActive);
}

void pulseAlertOutput(unsigned long durationMs) {
  commandPulseUntilMs = millis() + durationMs;
  refreshAlertOutput();
}

void buildMotionState(uint8_t heartRate, uint8_t &activity, uint8_t &flags) {
  const float accelG = readAccelerationMagnitudeG();
  const float movementDelta = fabs(accelG - lastAccelG);
  const bool impact = accelG > IMPACT_THRESHOLD_G;
  const bool movement = movementDelta > MOVEMENT_DELTA_G;
  const bool manualSos = digitalRead(SOS_BUTTON_PIN) == LOW;
  lastAccelG = accelG;

  criticalNow = false;
  if (heartRate > 0 &&
      previousHeartRate > 0 &&
      previousHeartRate - heartRate >= SUDDEN_HR_DROP_BPM) {
    criticalNow = true;
  }
  previousHeartRate = heartRate;

  if ((impact || manualSos) && !fallCountdownActive) {
    fallCountdownActive = true;
    fallStartedMs = millis();
  }

  // If the person moves after the fall impact, stop the countdown.
  if (fallCountdownActive && movement && !impact) {
    fallCountdownActive = false;
    fallStartedMs = 0;
    appAlertActive = false;
    commandPulseUntilMs = 0;
    refreshAlertOutput();
  }

  const bool timerExpired = fallCountdownActive && millis() - fallStartedMs >= FALL_COUNTDOWN_MS;
  const bool immediateCritical = fallCountdownActive && criticalNow;

  flags = 0;
  if (fallCountdownActive) flags |= FLAG_FALL | FLAG_SOS_COUNTDOWN;
  if (movement && !impact) flags |= FLAG_MOVEMENT;
  if (timerExpired || immediateCritical) flags |= FLAG_CRITICAL;
  if (manualSos) flags |= FLAG_MANUAL_SOS;

  if (timerExpired) {
    activity = ACTIVITY_NO_MOVEMENT;
  } else if (fallCountdownActive) {
    activity = ACTIVITY_FALL;
  } else if (movement) {
    activity =
        movementDelta > RUNNING_DELTA_G ? ACTIVITY_RUNNING : ACTIVITY_WALKING;
  } else {
    activity = ACTIVITY_RESTING;
  }

  // Local warning while countdown is active. App sends the actual SOS.
  refreshAlertOutput();
}

void notifyMetrics() {
  const uint8_t heartRate = readHeartRate();
  const uint8_t spo2 = readSpo2();
  const uint8_t hrv = readHrv();
  const uint8_t gsr = readGsrLevel();
  const int16_t tempX100 = readBodyTempX100();
  const int16_t ecgMvX1000 = readEcgMvX1000();
  const int32_t latitudeE7 = readGpsLatitudeE7();
  const int32_t longitudeE7 = readGpsLongitudeE7();
  const uint16_t gpsAccuracyX10 = readGpsAccuracyX10();
  const int batteryPct = readBatteryPct();

  uint8_t activity = ACTIVITY_RESTING;
  uint8_t flags = 0;
  buildMotionState(heartRate, activity, flags);
  const uint8_t stress = computeStress(gsr, hrv, heartRate, tempX100, activity);

  const bool movement = !fallCountdownActive || (flags & FLAG_MOVEMENT) != 0;
  const bool critical = (flags & FLAG_CRITICAL) != 0;
  const char *eventName = critical
                              ? "critical_fall"
                              : fallCountdownActive
                                  ? "fall_detected"
                                  : "none";
  const float tempC = tempX100 / 100.0f;
  const float ecgMv = ecgMvX1000 / 1000.0f;
  const float latitude = latitudeE7 / 10000000.0f;
  const float longitude = longitudeE7 / 10000000.0f;
  const float gpsAccuracy = gpsAccuracyX10 / 10.0f;
  const char *activityName = activity == ACTIVITY_WALKING
                                 ? "Walking"
                                 : activity == ACTIVITY_RUNNING
                                     ? "Running"
                                     : activity == ACTIVITY_FALL
                                         ? "Fall detected"
                                         : activity == ACTIVITY_NO_MOVEMENT
                                             ? "No movement"
                                             : "Resting";

  char payload[280];
  snprintf(
      payload,
      sizeof(payload),
      "{\"event\":\"%s\",\"ts\":%lu,\"hr\":%u,\"sp\":%u,\"hrv\":%u,\"gsr\":%u,"
      "\"tp\":%.2f,\"st\":%u,\"ac\":%u,\"activity\":\"%s\","
      "\"flags\":%u,\"mv\":%u,\"bt\":%d,\"ecg\":%.3f,"
      "\"lat\":%.7f,\"lon\":%.7f,\"gps\":%.1f}",
      eventName,
      millis() / 1000,
      heartRate,
      spo2,
      hrv,
      gsr,
      tempC,
      stress,
      activity,
      activityName,
      flags,
      movement ? 1 : 0,
      batteryPct,
      ecgMv,
      latitude,
      longitude,
      gpsAccuracy);

  metricsCharacteristic->setValue((uint8_t *)payload, strlen(payload));
  metricsCharacteristic->notify();

  Serial.println(payload);
}

void setupBle() {
  BLEDevice::init(DEVICE_NAME);
  BLEDevice::setMTU(185);
  BLEServer *server = BLEDevice::createServer();
  server->setCallbacks(new ServerCallbacks());

  BLEService *service = server->createService(SERVICE_UUID);
  metricsCharacteristic = service->createCharacteristic(
      METRICS_UUID,
      BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);
  metricsCharacteristic->addDescriptor(new BLE2902());
  BLECharacteristic *commandCharacteristic = service->createCharacteristic(
      COMMAND_UUID,
      BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR);
  commandCharacteristic->setCallbacks(new CommandCallbacks());
  service->start();

  BLEAdvertising *advertising = BLEDevice::getAdvertising();
  advertising->addServiceUUID(SERVICE_UUID);
  advertising->setScanResponse(true);
  advertising->setMinPreferred(0x06);
  advertising->setMinPreferred(0x12);
  BLEDevice::startAdvertising();
}

void setup() {
  Serial.begin(115200);
  Serial1.begin(9600, SERIAL_8N1, GPS_RX_PIN, GPS_TX_PIN);
  analogReadResolution(12);
  Wire.begin(I2C_SDA_PIN, I2C_SCL_PIN);

  pinMode(GSR_PIN, INPUT);
  pinMode(ECG_PIN, INPUT);
  pinMode(BATTERY_PIN, INPUT);
  pinMode(SOS_BUTTON_PIN, INPUT_PULLUP);
  pinMode(BUZZER_PIN, OUTPUT);
  pinMode(VIBRATION_PIN, OUTPUT);
  pinMode(STATUS_LED_PIN, OUTPUT);
  setAlertOutput(false);
  digitalWrite(STATUS_LED_PIN, LOW);

  randomSeed(esp_random());
  initMax30102();
  initMpu6050();
  setupBle();
  Serial.println("NeuroGuardianX BLE wearable advertising");
}

void loop() {
  sampleMax30102();
  sampleGps();
  refreshAlertOutput();

  if (deviceConnected && millis() - lastNotifyMs >= NOTIFY_INTERVAL_MS) {
    lastNotifyMs = millis();
    notifyMetrics();
  }
  delay(10);
}

