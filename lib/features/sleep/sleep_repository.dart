import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

final sleepLogsProvider =
    StateNotifierProvider<SleepLogsController, AsyncValue<List<SleepLog>>>(
  (ref) => SleepLogsController(),
);

final sleepInsightsProvider = Provider<SleepInsights>((ref) {
  final logs = ref.watch(sleepLogsProvider).valueOrNull ?? const <SleepLog>[];
  return SleepInsights.fromLogs(logs);
});

class SleepLog {
  const SleepLog({
    required this.id,
    required this.date,
    required this.hours,
    required this.quality,
    required this.createdAt,
  });

  factory SleepLog.fromMap(Map raw) {
    return SleepLog(
      id: raw['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      date: DateTime.fromMillisecondsSinceEpoch(
        raw['date'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
      hours: (raw['hours'] as num?)?.toDouble() ?? 0,
      quality: (raw['quality'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        raw['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  final String id;
  final DateTime date;
  final double hours;
  final int quality;
  final DateTime createdAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'date': DateTime(date.year, date.month, date.day).millisecondsSinceEpoch,
      'hours': hours,
      'quality': quality,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }
}

class SleepInsights {
  const SleepInsights({
    required this.score,
    required this.avgHours,
    required this.avgQuality,
    required this.consistency,
    required this.tip,
    required this.nights,
  });

  factory SleepInsights.fromLogs(List<SleepLog> logs) {
    if (logs.isEmpty) {
      return const SleepInsights(
        score: 0,
        avgHours: 0,
        avgQuality: 0,
        consistency: 'No data',
        tip:
            'Log sleep for a few nights. Sleep quality helps explain stress and recovery patterns.',
        nights: 0,
      );
    }

    final recent = logs.take(7).toList();
    final avgHours =
        recent.map((e) => e.hours).reduce((a, b) => a + b) / recent.length;
    final avgQuality =
        recent.map((e) => e.quality).reduce((a, b) => a + b) / recent.length;
    final hoursScore = (100 - ((avgHours - 8).abs() * 18)).clamp(0, 100);
    final score = (hoursScore * 0.6 + avgQuality * 0.4).round();
    final variance = recent
            .map((e) => (e.hours - avgHours) * (e.hours - avgHours))
            .reduce((a, b) => a + b) /
        recent.length;
    final deviation = sqrt(variance);

    return SleepInsights(
      score: score,
      avgHours: avgHours,
      avgQuality: avgQuality.round(),
      consistency: deviation <= 0.7
          ? 'Consistent'
          : deviation <= 1.4
              ? 'Variable'
              : 'Irregular',
      tip: _tipFor(score, avgHours, avgQuality),
      nights: recent.length,
    );
  }

  final int score;
  final double avgHours;
  final int avgQuality;
  final String consistency;
  final String tip;
  final int nights;

  static String _tipFor(int score, double avgHours, double avgQuality) {
    if (avgHours < 6.5) {
      return 'Sleep duration is low. Plan an earlier wind-down and reduce late caffeine.';
    }
    if (avgHours > 9.5) {
      return 'Sleep duration is high. If fatigue continues, discuss it with a doctor.';
    }
    if (avgQuality < 60) {
      return 'Quality is low. Keep a steady bedtime, dim lights, and avoid screens before sleep.';
    }
    if (score >= 80) {
      return 'Recovery looks strong. Keep the same sleep window and hydration routine.';
    }
    return 'Sleep is close to target. Improve consistency for better stress recovery.';
  }
}

class SleepLogsController extends StateNotifier<AsyncValue<List<SleepLog>>> {
  SleepLogsController() : super(const AsyncValue.loading()) {
    reload();
  }

  static const _boxName = 'sleep_logs';

  Box<Map>? _box;

  Future<void> reload() async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await _readAll());
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> add({
    required DateTime date,
    required double hours,
    required int quality,
  }) async {
    final box = await _openBox();
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final existing = box.values
        .map(SleepLog.fromMap)
        .where((log) => _sameDay(log.date, normalizedDate))
        .toList();
    for (final log in existing) {
      await box.delete(log.id);
    }

    final log = SleepLog(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      date: normalizedDate,
      hours: hours.clamp(0, 14).toDouble(),
      quality: quality.clamp(0, 100).toInt(),
      createdAt: DateTime.now(),
    );
    await box.put(log.id, log.toMap());
    state = AsyncValue.data(await _readAll());
  }

  Future<void> remove(String id) async {
    final box = await _openBox();
    await box.delete(id);
    state = AsyncValue.data(await _readAll());
  }

  Future<List<SleepLog>> _readAll() async {
    final box = await _openBox();
    final items = box.values.map(SleepLog.fromMap).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return items;
  }

  Future<Box<Map>> _openBox() async {
    return _box ??= await Hive.openBox<Map>(_boxName);
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
