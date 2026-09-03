class Metrics {
  const Metrics({
    required this.timestamp,
    required this.heartRate,
    this.spo2,
    this.hrv,
    this.gsrLevel,
    this.ecgMv,
    this.latitude,
    this.longitude,
    this.gpsAccuracyM,
    this.batteryPct,
    required this.stressLevel,
    required this.temperatureC,
    required this.activity,
    this.fallDetected = false,
    this.movementDetected = true,
  });

  final DateTime timestamp;
  final int heartRate;
  final int? spo2;
  final double? hrv;
  final double? gsrLevel;
  final double? ecgMv;
  final double? latitude;
  final double? longitude;
  final double? gpsAccuracyM;
  final int? batteryPct;
  final double stressLevel; // 0-100
  final double temperatureC;
  final String activity;
  final bool fallDetected;
  final bool movementDetected;

  bool get hasHeartRate => heartRate >= 30 && heartRate <= 220;
  bool get hasSpo2 => spo2 != null && spo2! >= 50 && spo2! <= 100;
  bool get hasHrv => hrv != null && hrv! >= 1 && hrv! <= 200;
  bool get hasGsr => gsrLevel != null && gsrLevel! >= 0 && gsrLevel! <= 100;
  bool get hasEcg => ecgMv != null && ecgMv!.abs() <= 3.0;
  bool get hasBodyTemperature => temperatureC >= 30 && temperatureC <= 45;
  bool get hasWatchGps => latitude != null && longitude != null;
  bool get hasBattery =>
      batteryPct != null && batteryPct! >= 0 && batteryPct! <= 100;
  bool get hasCoreVitals => hasHeartRate && hasBodyTemperature;

  String get sensorQualityLabel {
    if (hasCoreVitals && hasSpo2) return 'Real sensor data';
    if (hasHeartRate || hasSpo2 || hasBodyTemperature) {
      return 'Partial sensor data';
    }
    if (fallDetected || !movementDetected) return 'Motion-only alert';
    return 'Waiting for sensors';
  }

  Metrics copyWith({
    DateTime? timestamp,
    int? heartRate,
    int? spo2,
    double? hrv,
    double? gsrLevel,
    double? ecgMv,
    double? latitude,
    double? longitude,
    double? gpsAccuracyM,
    int? batteryPct,
    double? stressLevel,
    double? temperatureC,
    String? activity,
    bool? fallDetected,
    bool? movementDetected,
  }) {
    return Metrics(
      timestamp: timestamp ?? this.timestamp,
      heartRate: heartRate ?? this.heartRate,
      spo2: spo2 ?? this.spo2,
      hrv: hrv ?? this.hrv,
      gsrLevel: gsrLevel ?? this.gsrLevel,
      ecgMv: ecgMv ?? this.ecgMv,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      gpsAccuracyM: gpsAccuracyM ?? this.gpsAccuracyM,
      batteryPct: batteryPct ?? this.batteryPct,
      stressLevel: stressLevel ?? this.stressLevel,
      temperatureC: temperatureC ?? this.temperatureC,
      activity: activity ?? this.activity,
      fallDetected: fallDetected ?? this.fallDetected,
      movementDetected: movementDetected ?? this.movementDetected,
    );
  }
}

class RiskScores {
  const RiskScores({
    required this.stressIndex,
    required this.cardiacRisk,
    required this.emergencyProb,
    required this.healthScore,
    required this.level,
    required this.summary,
  });

  final double stressIndex;
  final double cardiacRisk;
  final double emergencyProb;
  final double healthScore;
  final RiskLevel level;
  final String summary;

  RiskScores copyWith({
    double? stressIndex,
    double? cardiacRisk,
    double? emergencyProb,
    double? healthScore,
    RiskLevel? level,
    String? summary,
  }) {
    return RiskScores(
      stressIndex: stressIndex ?? this.stressIndex,
      cardiacRisk: cardiacRisk ?? this.cardiacRisk,
      emergencyProb: emergencyProb ?? this.emergencyProb,
      healthScore: healthScore ?? this.healthScore,
      level: level ?? this.level,
      summary: summary ?? this.summary,
    );
  }
}

enum RiskLevel { stable, watch, urgent }

extension RiskLevelLabel on RiskLevel {
  String get label {
    switch (this) {
      case RiskLevel.stable:
        return 'Stable';
      case RiskLevel.watch:
        return 'Watch';
      case RiskLevel.urgent:
        return 'Urgent';
    }
  }
}
