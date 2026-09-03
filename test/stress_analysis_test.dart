import 'package:flutter_test/flutter_test.dart';
import 'package:neuroguardian_app/features/metrics/metrics.dart';
import 'package:neuroguardian_app/features/metrics/stress_analysis.dart';

void main() {
  Metrics sample({
    required DateTime timestamp,
    required int heartRate,
    required double hrv,
    required double gsr,
    required double stress,
    required double temperatureC,
    String activity = 'Resting',
    bool movementDetected = true,
  }) {
    return Metrics(
      timestamp: timestamp,
      heartRate: heartRate,
      hrv: hrv,
      gsrLevel: gsr,
      stressLevel: stress,
      temperatureC: temperatureC,
      activity: activity,
      movementDetected: movementDetected,
    );
  }

  test('detects elevated stress against a personal baseline', () {
    final now = DateTime(2026, 9, 3, 10);
    final samples = <Metrics>[
      for (var i = 0; i < 5; i++)
        sample(
          timestamp: now.subtract(Duration(seconds: i * 2)),
          heartRate: 106,
          hrv: 20,
          gsr: 88,
          stress: 84,
          temperatureC: 37.3,
        ),
      for (var i = 5; i < 25; i++)
        sample(
          timestamp: now.subtract(Duration(seconds: i * 2)),
          heartRate: 72,
          hrv: 56,
          gsr: 30,
          stress: 32,
          temperatureC: 36.7,
        ),
    ];

    final insight = analyzeStressPattern(samples);

    expect(insight.score, greaterThan(70));
    expect(insight.level, isNot(StressPatternLevel.calm));
    expect(insight.motionFilterActive, isFalse);
  });

  test('reduces stress confidence while the user is running', () {
    final now = DateTime(2026, 9, 3, 10);
    final samples = <Metrics>[
      sample(
        timestamp: now,
        heartRate: 126,
        hrv: 50,
        gsr: 50,
        stress: 60,
        temperatureC: 36.9,
        activity: 'Running',
      ),
      for (var i = 1; i < 20; i++)
        sample(
          timestamp: now.subtract(Duration(seconds: i * 2)),
          heartRate: 72,
          hrv: 56,
          gsr: 32,
          stress: 34,
          temperatureC: 36.7,
        ),
    ];

    final insight = analyzeStressPattern(samples);

    expect(insight.motionFilterActive, isTrue);
    expect(insight.score, lessThan(55));
    expect(insight.level, isNot(StressPatternLevel.high));
  });
}
