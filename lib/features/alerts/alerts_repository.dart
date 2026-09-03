import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';

import 'alert_event.dart';

class SafetyAlertRepository {
  static const _boxName = 'safety_alerts';

  Box<Map>? _box;

  Future<void> init() async {
    _box ??= await Hive.openBox<Map>(_boxName);
  }

  Future<void> add(SafetyAlert alert) async {
    final box = _box;
    if (box == null) return;
    await box.put(alert.id, alert.toMap());
    if (box.length > 500) {
      await box.deleteAt(0);
    }
  }

  List<SafetyAlert> latest({int limit = 100}) {
    final box = _box;
    if (box == null) return [];
    final values = box.values.toList().cast<Map>();
    return values.reversed.take(limit).map(SafetyAlert.fromMap).toList();
  }

  Stream<List<SafetyAlert>> watch({int limit = 100}) {
    final controller = StreamController<List<SafetyAlert>>();
    void emit() => controller.add(latest(limit: limit));
    emit();
    final sub = _box?.watch().listen((_) => emit());
    controller.onCancel = () => sub?.cancel();
    return controller.stream;
  }

  Future<void> clear() async {
    await _box?.clear();
  }
}
