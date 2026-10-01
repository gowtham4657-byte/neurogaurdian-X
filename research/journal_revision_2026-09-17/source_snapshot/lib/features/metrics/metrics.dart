import 'dart:math' as math;

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
    this.packetVersion = 1,
    this.accelXG,
    this.accelYG,
    this.accelZG,
    this.gyroXDps,
    this.gyroYDps,
    this.gyroZDps,
    this.pressureHpa,
    this.altitudeM,
    this.ppgQuality,
    this.ecgQuality,
    this.gsrQuality,
    this.temperatureQuality,
    this.watchFit,
    this.skinContact,
    this.sensorFlags = 0,
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
  final int packetVersion;
  final double? accelXG;
  final double? accelYG;
  final double? accelZG;
  final double? gyroXDps;
  final double? gyroYDps;
  final double? gyroZDps;
  final double? pressureHpa;
  final double? altitudeM;
  final double? ppgQuality; // 0-1
  final double? ecgQuality; // 0-1
  final double? gsrQuality; // 0-1
  final double? temperatureQuality; // 0-1
  final bool? watchFit;
  final bool? skinContact;
  final int sensorFlags;
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
  bool get hasAccelerometer =>
      accelXG != null && accelYG != null && accelZG != null;
  bool get hasGyroscope =>
      gyroXDps != null && gyroYDps != null && gyroZDps != null;
  bool get hasPressure => pressureHpa != null && pressureHpa! >= 300;
  bool get hasAltitude => altitudeM != null;
  bool get hasAnySignalQuality =>
      ppgQuality != null ||
      ecgQuality != null ||
      gsrQuality != null ||
      temperatureQuality != null;
  bool get hasBattery =>
      batteryPct != null && batteryPct! >= 0 && batteryPct! <= 100;
  bool get hasCoreVitals => hasHeartRate && hasBodyTemperature;

  double? get accelerationMagnitudeG {
    if (!hasAccelerometer) return null;
    final x = accelXG!;
    final y = accelYG!;
    final z = accelZG!;
    return math.sqrt(x * x + y * y + z * z);
  }

  double get overallSignalQuality {
    final values = <double>[
      if (ppgQuality != null) ppgQuality!.clamp(0, 1).toDouble(),
      if (ecgQuality != null) ecgQuality!.clamp(0, 1).toDouble(),
      if (gsrQuality != null) gsrQuality!.clamp(0, 1).toDouble(),
      if (temperatureQuality != null)
        temperatureQuality!.clamp(0, 1).toDouble(),
    ];
    if (values.isEmpty) {
      if (hasCoreVitals && hasSpo2) return 0.72;
      if (hasHeartRate || hasSpo2 || hasBodyTemperature) return 0.48;
      if (fallDetected || !movementDetected) return 0.55;
      return 0;
    }
    return values.reduce((a, b) => a + b) / values.length;
  }

  String get sensorQualityLabel {
    final contactKnown = watchFit ?? skinContact;
    if (contactKnown == false) return 'Check watch fit';
    if (hasAnySignalQuality && overallSignalQuality < 0.45) {
      return 'Poor sensor contact';
    }
    if (hasAnySignalQuality && overallSignalQuality < 0.65) {
      return 'Limited sensor quality';
    }
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
    int? packetVersion,
    double? accelXG,
    double? accelYG,
    double? accelZG,
    double? gyroXDps,
    double? gyroYDps,
    double? gyroZDps,
    double? pressureHpa,
    double? altitudeM,
    double? ppgQuality,
    double? ecgQuality,
    double? gsrQuality,
    double? temperatureQuality,
    bool? watchFit,
    bool? skinContact,
    int? sensorFlags,
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
      packetVersion: packetVersion ?? this.packetVersion,
      accelXG: accelXG ?? this.accelXG,
      accelYG: accelYG ?? this.accelYG,
      accelZG: accelZG ?? this.accelZG,
      gyroXDps: gyroXDps ?? this.gyroXDps,
      gyroYDps: gyroYDps ?? this.gyroYDps,
      gyroZDps: gyroZDps ?? this.gyroZDps,
      pressureHpa: pressureHpa ?? this.pressureHpa,
      altitudeM: altitudeM ?? this.altitudeM,
      ppgQuality: ppgQuality ?? this.ppgQuality,
      ecgQuality: ecgQuality ?? this.ecgQuality,
      gsrQuality: gsrQuality ?? this.gsrQuality,
      temperatureQuality: temperatureQuality ?? this.temperatureQuality,
      watchFit: watchFit ?? this.watchFit,
      skinContact: skinContact ?? this.skinContact,
      sensorFlags: sensorFlags ?? this.sensorFlags,
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
