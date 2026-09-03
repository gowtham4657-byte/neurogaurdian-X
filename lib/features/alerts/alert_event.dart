import '../metrics/metrics.dart';

enum SafetyAlertSeverity { info, watch, urgent }

class SafetyAlert {
  const SafetyAlert({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.severity,
    required this.createdAt,
    this.heartRate,
    this.spo2,
    this.stressLevel,
    this.temperatureC,
    this.latitude,
    this.longitude,
  });

  factory SafetyAlert.fromMetrics({
    required String type,
    required String title,
    required String message,
    required SafetyAlertSeverity severity,
    required Metrics metrics,
  }) {
    return SafetyAlert(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: type,
      title: title,
      message: message,
      severity: severity,
      createdAt: DateTime.now(),
      heartRate: metrics.hasHeartRate ? metrics.heartRate : null,
      spo2: metrics.hasSpo2 ? metrics.spo2 : null,
      stressLevel: metrics.stressLevel,
      temperatureC: metrics.hasBodyTemperature ? metrics.temperatureC : null,
      latitude: metrics.latitude,
      longitude: metrics.longitude,
    );
  }

  factory SafetyAlert.fromMap(Map raw) {
    return SafetyAlert(
      id: raw['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      type: raw['type'] as String? ?? 'system',
      title: raw['title'] as String? ?? 'Safety alert',
      message: raw['message'] as String? ?? '',
      severity: SafetyAlertSeverity.values.firstWhere(
        (value) => value.name == raw['severity'],
        orElse: () => SafetyAlertSeverity.info,
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        raw['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
      heartRate: (raw['heartRate'] as num?)?.toInt(),
      spo2: (raw['spo2'] as num?)?.toInt(),
      stressLevel: (raw['stressLevel'] as num?)?.toDouble(),
      temperatureC: (raw['temperatureC'] as num?)?.toDouble(),
      latitude: (raw['latitude'] as num?)?.toDouble(),
      longitude: (raw['longitude'] as num?)?.toDouble(),
    );
  }

  final String id;
  final String type;
  final String title;
  final String message;
  final SafetyAlertSeverity severity;
  final DateTime createdAt;
  final int? heartRate;
  final int? spo2;
  final double? stressLevel;
  final double? temperatureC;
  final double? latitude;
  final double? longitude;

  bool get hasLocation => latitude != null && longitude != null;

  String get vitalsLine {
    final values = [
      if (heartRate != null) 'HR $heartRate bpm',
      if (spo2 != null) 'SpO2 $spo2%',
      if (stressLevel != null) 'stress ${stressLevel!.toStringAsFixed(0)}',
      if (temperatureC != null) 'temp ${temperatureC!.toStringAsFixed(1)} C',
    ];
    return values.isEmpty ? 'No valid vitals snapshot' : values.join(' - ');
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'message': message,
      'severity': severity.name,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'heartRate': heartRate,
      'spo2': spo2,
      'stressLevel': stressLevel,
      'temperatureC': temperatureC,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}
