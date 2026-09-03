import '../metrics/metrics.dart';

class DetectionRecord {
  DetectionRecord({
    required this.database,
    required this.title,
    required this.summary,
    required this.trigger,
    required this.action,
    required this.sensors,
    required this.severity,
    required this.confidence,
    required this.isActive,
  });

  final String database;
  final String title;
  final String summary;
  final String trigger;
  final String action;
  final List<String> sensors;
  final DetectionSeverity severity;
  final double Function(Metrics metrics, RiskScores? risk) confidence;
  final bool Function(Metrics metrics, RiskScores? risk) isActive;

  DetectionResult evaluate(Metrics metrics, RiskScores? risk) {
    final value = confidence(metrics, risk).clamp(0, 100).toDouble();
    return DetectionResult(
      record: this,
      confidence: value,
      active: isActive(metrics, risk),
    );
  }
}

class DetectionResult {
  const DetectionResult({
    required this.record,
    required this.confidence,
    required this.active,
  });

  final DetectionRecord record;
  final double confidence;
  final bool active;
}

enum DetectionSeverity {
  stable,
  watch,
  urgent,
}

final detectionDatabase = <DetectionRecord>[
  DetectionRecord(
    database: 'PhysioNet ECG Risk DB',
    title: 'Cardiac distress pattern',
    summary:
        'Model-ready cardiac rules aligned to MIT-BIH/SDDB style ECG evidence, plus wearable HR, HRV, and SpO2 signals.',
    trigger: 'HR >= 125 bpm, SpO2 <= 92, or HR >= 115 bpm with HRV <= 30.',
    action:
        'Stop activity, sit upright, hydrate, and use SOS if symptoms continue.',
    sensors: const ['MAX30102 HR/SpO2', 'HRV', 'GSR stress', 'AD8232 ECG'],
    severity: DetectionSeverity.urgent,
    confidence: (m, risk) {
      final hrvLoad = m.hasHrv ? (100 - m.hrv!).clamp(0, 100) : 0.0;
      return (risk?.cardiacRisk ?? 0) * 0.7 +
          hrvLoad * 0.2 +
          (m.hasSpo2 && m.spo2! <= 92 ? 20 : 0) +
          (m.hasHeartRate && m.heartRate >= 125 ? 20 : 0);
    },
    isActive: (m, risk) {
      final hrv = m.hasHrv ? m.hrv! : 60;
      return (m.hasHeartRate && m.heartRate >= 125) ||
          (m.hasSpo2 && m.spo2! <= 92) ||
          (m.hasHeartRate && m.heartRate >= 115 && hrv <= 30) ||
          (risk?.cardiacRisk ?? 0) >= 70;
    },
  ),
  DetectionRecord(
    database: 'Wearable Stress DB',
    title: 'Stress overload pattern',
    summary:
        'Combines GSR/EDA, HRV drop, heart-rate load, temperature, and movement like wearable stress datasets.',
    trigger: 'Stress >= 70 or AI stress index >= 70.',
    action:
        'Begin breathing cycle, reduce stimulation, and recheck in five minutes.',
    sensors: const ['GSR', 'HRV', 'MAX30102 HR', 'MPU6050 motion'],
    severity: DetectionSeverity.watch,
    confidence: (m, risk) => (risk?.stressIndex ?? m.gsrLevel ?? m.stressLevel),
    isActive: (m, risk) =>
        m.stressLevel >= 70 ||
        (m.gsrLevel ?? 0) >= 70 ||
        (risk?.stressIndex ?? 0) >= 70,
  ),
  DetectionRecord(
    database: 'Oxygen Safety DB',
    title: 'SpO2 oxygen drop pattern',
    summary:
        'Uses MAX30102 SpO2 with heart-rate load to detect low oxygen patterns.',
    trigger: 'SpO2 <= 92 as watch; <= 90 as urgent.',
    action:
        'Rest upright, recheck sensor placement, and seek help if symptoms appear.',
    sensors: const ['MAX30102 SpO2', 'heart rate', 'motion'],
    severity: DetectionSeverity.urgent,
    confidence: (m, risk) =>
        !m.hasSpo2 ? 0 : ((95 - m.spo2!) / 8 * 100).clamp(0, 100).toDouble(),
    isActive: (m, risk) => m.hasSpo2 && m.spo2! <= 92,
  ),
  DetectionRecord(
    database: 'Recovery Trend DB',
    title: 'Long stress buildup pattern',
    summary:
        'Combines GSR, stress index, low HRV, sleep/recovery history, and trend-ready data for burnout warnings.',
    trigger: 'GSR >= 75 or AI stress index >= 75.',
    action:
        'Reduce stimulation, rest, hydrate, and review sleep/recovery pattern.',
    sensors: const ['GSR', 'HRV', 'history trend', 'AI stress index'],
    severity: DetectionSeverity.watch,
    confidence: (m, risk) =>
        ((m.gsrLevel ?? m.stressLevel) * 0.55 + (risk?.stressIndex ?? 0) * 0.45)
            .clamp(0, 100)
            .toDouble(),
    isActive: (m, risk) =>
        (m.gsrLevel ?? 0) >= 75 || (risk?.stressIndex ?? 0) >= 75,
  ),
  DetectionRecord(
    database: 'Body Temperature DB',
    title: 'Heat strain pattern',
    summary:
        'Monitors body temperature with heart-rate load and activity intensity.',
    trigger: 'Temperature >= 37.8 C, or >= 38.5 C as urgent.',
    action: 'Cool down, rest, and monitor temperature trend.',
    sensors: const ['DS18B20 temperature', 'MAX30102 HR', 'MPU6050 motion'],
    severity: DetectionSeverity.watch,
    confidence: (m, risk) => m.hasBodyTemperature
        ? ((m.temperatureC - 36.5) / 2.0 * 100).clamp(0, 100).toDouble()
        : 0,
    isActive: (m, risk) => m.hasBodyTemperature && m.temperatureC >= 37.8,
  ),
  DetectionRecord(
    database: 'Fall Detection DB',
    title: 'Fall emergency routing',
    summary:
        'Uses impact/fall flag, movement inactivity, and sudden heart-rate drop before routing SOS.',
    trigger:
        'Immediate SOS for fall + sudden HR drop; otherwise SOS after 30 seconds no movement.',
    action:
        'Movement cancels the timer. Critical fall routes SOS to hospital/ambulance contact.',
    sensors: const [
      'MPU6050 accel/gyro',
      'MAX30102 HR',
      'GPS',
      'SIM/SMS',
      'touch cancel'
    ],
    severity: DetectionSeverity.urgent,
    confidence: (m, risk) {
      if (m.fallDetected && !m.movementDetected) return 100;
      if (!m.movementDetected) return 70;
      return 0;
    },
    isActive: (m, risk) => m.fallDetected || !m.movementDetected,
  ),
  DetectionRecord(
    database: 'Watch Signal DB',
    title: 'Wearable packet health',
    summary:
        'Checks that the watch is sending heart, HRV, stress, temperature, and motion.',
    trigger: 'Live sample received from ESP32 BLE notifications.',
    action: 'Keep Bluetooth active and maintain sensor skin contact.',
    sensors: const [
      'ESP32 BLE',
      'packet flags',
      'timestamp',
      'battery-ready stream'
    ],
    severity: DetectionSeverity.stable,
    confidence: (m, risk) =>
        m.hasCoreVitals || m.fallDetected || !m.movementDetected ? 100 : 35,
    isActive: (m, risk) =>
        m.hasCoreVitals || m.fallDetected || !m.movementDetected,
  ),
];
