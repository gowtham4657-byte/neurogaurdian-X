import 'package:flutter_test/flutter_test.dart';
import 'package:neuroguardian_app/features/metrics/metrics.dart';
import 'package:neuroguardian_app/features/neurotwin/neurotwin_engine.dart';
import 'package:neuroguardian_app/features/neurotwin/neurotwin_models.dart';

void main() {
  Metrics sample({
    required DateTime timestamp,
    int heartRate = 72,
    int spo2 = 98,
    double hrv = 48,
    double gsr = 32,
    double ecgMv = 0.62,
    double temp = 36.7,
    double stress = 32,
    String activity = 'Resting',
    bool fallDetected = false,
    bool movementDetected = true,
    double ppgQuality = 0.9,
    double ecgQuality = 0.86,
    double gsrQuality = 0.82,
  }) {
    return Metrics(
      timestamp: timestamp,
      heartRate: heartRate,
      spo2: spo2,
      hrv: hrv,
      gsrLevel: gsr,
      ecgMv: ecgMv,
      stressLevel: stress,
      temperatureC: temp,
      activity: activity,
      fallDetected: fallDetected,
      movementDetected: movementDetected,
      ppgQuality: ppgQuality,
      ecgQuality: ecgQuality,
      gsrQuality: gsrQuality,
      temperatureQuality: 0.8,
      watchFit: true,
      skinContact: true,
    );
  }

  test('normal clean baseline remains normal', () {
    final now = DateTime(2026, 9, 9, 10);
    final history = [
      for (var i = 1; i <= 30; i++)
        sample(timestamp: now.subtract(Duration(seconds: i * 5))),
    ];

    final snapshot = const NeuroTwinEngine().build(
      latest: sample(timestamp: now),
      history: history,
    );

    expect(snapshot, isNotNull);
    expect(snapshot!.baseline.ready, isTrue);
    expect(snapshot.category, NeuroTwinRiskCategory.normal);
  });

  test('fall without movement becomes critical review candidate', () {
    final now = DateTime(2026, 9, 9, 10);
    final snapshot = const NeuroTwinEngine().build(
      latest: sample(
        timestamp: now,
        heartRate: 78,
        activity: 'Fall detected',
        fallDetected: true,
        movementDetected: false,
      ),
      history: const [],
    );

    expect(snapshot, isNotNull);
    expect(snapshot!.category, NeuroTwinRiskCategory.criticalReview);
    expect(snapshot.algorithm.fallProbability, greaterThan(80));
  });
}
