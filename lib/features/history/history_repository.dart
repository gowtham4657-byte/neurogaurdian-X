import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';

import '../metrics/metrics.dart';

/// Persists incoming metrics for later trend rendering.
class HistoryRepository {
  static const _boxName = 'history';

  Box<Map>? _box;

  Future<void> init() async {
    _box ??= await Hive.openBox<Map>(_boxName);
  }

  Future<void> add(Metrics m) async {
    final box = _box;
    if (box == null) return;
    await box.add(_toMap(m));
    if (box.length > 1000) {
      await box.deleteAt(0);
    }
  }

  List<Metrics> latest({int limit = 100}) {
    final box = _box;
    if (box == null) return [];
    final values = box.values.toList().cast<Map>();
    return values.reversed.take(limit).map(_fromMap).toList();
  }

  Stream<List<Metrics>> watch({int limit = 100}) {
    final controller = StreamController<List<Metrics>>();
    void emit() => controller.add(latest(limit: limit));
    emit();
    final sub = _box?.watch().listen((_) => emit());
    controller.onCancel = () => sub?.cancel();
    return controller.stream;
  }

  Future<void> clear() async {
    await _box?.clear();
  }

  Map<String, Object?> _toMap(Metrics m) => {
        'ts': m.timestamp.millisecondsSinceEpoch,
        'hr': m.heartRate,
        'spo2': m.spo2,
        'hrv': m.hrv,
        'gsr': m.gsrLevel,
        'ecg': m.ecgMv,
        'lat': m.latitude,
        'lon': m.longitude,
        'gpsAcc': m.gpsAccuracyM,
        'battery': m.batteryPct,
        'stress': m.stressLevel,
        'temp': m.temperatureC,
        'activity': m.activity,
        'fall': m.fallDetected,
        'movement': m.movementDetected,
      };

  Metrics _fromMap(Map raw) {
    return Metrics(
      timestamp: DateTime.fromMillisecondsSinceEpoch(raw['ts'] as int),
      heartRate: raw['hr'] as int,
      spo2: raw['spo2'] as int?,
      hrv: (raw['hrv'] as num?)?.toDouble(),
      gsrLevel: (raw['gsr'] as num?)?.toDouble(),
      ecgMv: (raw['ecg'] as num?)?.toDouble(),
      latitude: (raw['lat'] as num?)?.toDouble(),
      longitude: (raw['lon'] as num?)?.toDouble(),
      gpsAccuracyM: (raw['gpsAcc'] as num?)?.toDouble(),
      batteryPct: (raw['battery'] as num?)?.toInt(),
      stressLevel: (raw['stress'] as num).toDouble(),
      temperatureC: (raw['temp'] as num).toDouble(),
      activity: raw['activity'] as String? ?? 'Unknown',
      fallDetected: raw['fall'] as bool? ?? false,
      movementDetected: raw['movement'] as bool? ?? true,
    );
  }
}
