import '../metrics/metrics.dart';
import '../metrics/metrics_providers.dart';
import 'neurotwin_models.dart';

class TrendAnalyzer {
  const TrendAnalyzer();

  TrendResult analyze({
    required Metrics latest,
    required List<Metrics> history,
  }) {
    final samples = <Metrics>[latest, ...history]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final now = latest.timestamp;
    final five = _averageRisk(samples, now, const Duration(minutes: 5));
    final thirty = _averageRisk(samples, now, const Duration(minutes: 30));
    final hour = _averageRisk(samples, now, const Duration(hours: 1));

    final older = _averageRisk(
      samples
          .where(
              (m) => now.difference(m.timestamp) > const Duration(minutes: 5))
          .toList(),
      now,
      const Duration(hours: 1),
    );
    final delta = five == null || older == null ? 0 : five - older;
    final direction = delta >= 12
        ? 'Increasing'
        : delta <= -10
            ? 'Improving'
            : 'Stable';

    return TrendResult(
      fiveMinuteAverage: five,
      thirtyMinuteAverage: thirty,
      oneHourAverage: hour,
      direction: direction,
      message: _message(direction, samples.length),
    );
  }

  double? _averageRisk(
    List<Metrics> samples,
    DateTime now,
    Duration window,
  ) {
    final values = samples
        .where((m) => now.difference(m.timestamp).abs() <= window)
        .map((m) => calculateRiskScores(m).emergencyProb)
        .toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  String _message(String direction, int sampleCount) {
    if (sampleCount < 8) {
      return 'Collecting more samples before making a strong trend statement.';
    }
    switch (direction) {
      case 'Increasing':
        return 'Risk pattern is rising across recent samples. Recheck sensor fit and observe symptoms.';
      case 'Improving':
        return 'Recent values are moving closer to the normal pattern.';
      default:
        return 'Risk pattern is stable in the recent window.';
    }
  }
}
