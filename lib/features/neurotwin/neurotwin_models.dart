import '../metrics/metrics.dart';

enum NeuroTwinRiskCategory { normal, observe, warning, criticalReview }

extension NeuroTwinRiskCategoryLabel on NeuroTwinRiskCategory {
  String get label {
    switch (this) {
      case NeuroTwinRiskCategory.normal:
        return 'Normal';
      case NeuroTwinRiskCategory.observe:
        return 'Observe';
      case NeuroTwinRiskCategory.warning:
        return 'Warning';
      case NeuroTwinRiskCategory.criticalReview:
        return 'Critical Review';
    }
  }
}

class BaselineMetric {
  const BaselineMetric({
    required this.key,
    required this.label,
    required this.unit,
    required this.current,
    required this.mean,
    required this.stdDeviation,
    required this.sampleCount,
    this.minimumUsefulSamples = 12,
  });

  final String key;
  final String label;
  final String unit;
  final double? current;
  final double? mean;
  final double? stdDeviation;
  final int sampleCount;
  final int minimumUsefulSamples;

  bool get hasCurrent => current != null;
  bool get ready =>
      sampleCount >= minimumUsefulSamples &&
      current != null &&
      mean != null &&
      stdDeviation != null;
  double? get deviation =>
      current == null || mean == null ? null : current! - mean!;
  double? get zScore {
    final std = stdDeviation;
    if (current == null || mean == null || std == null || std < 0.01) {
      return null;
    }
    return (current! - mean!) / std;
  }
}

class BaselineProfile {
  const BaselineProfile({
    required this.activityContext,
    required this.metrics,
    required this.validSampleCount,
    required this.lastUpdated,
  });

  final String activityContext;
  final List<BaselineMetric> metrics;
  final int validSampleCount;
  final DateTime? lastUpdated;

  bool get ready => validSampleCount >= 20;
  double get completion => (validSampleCount / 20).clamp(0, 1).toDouble();
  String get statusLabel => ready ? 'Baseline ready' : 'Learning baseline';
}

class SensorQuality {
  const SensorQuality({
    required this.ppg,
    required this.ecg,
    required this.gsr,
    required this.temperature,
    required this.motion,
    required this.gps,
    required this.overall,
    required this.watchFit,
    required this.notes,
  });

  final double ppg;
  final double ecg;
  final double gsr;
  final double temperature;
  final double motion;
  final double gps;
  final double overall;
  final bool watchFit;
  final List<String> notes;

  bool get reliableForRisk => overall >= 0.55 && watchFit;
  String get label {
    if (!watchFit) return 'Check watch fit';
    if (overall >= 0.75) return 'Good';
    if (overall >= 0.55) return 'Usable';
    if (overall >= 0.35) return 'Limited';
    return 'Poor';
  }
}

class AlgorithmOutput {
  const AlgorithmOutput({
    required this.stressScore,
    required this.ecgAnomalyProbability,
    required this.fallProbability,
    required this.activity,
  });

  final double stressScore;
  final double ecgAnomalyProbability;
  final double fallProbability;
  final String activity;
}

class TrendResult {
  const TrendResult({
    required this.fiveMinuteAverage,
    required this.thirtyMinuteAverage,
    required this.oneHourAverage,
    required this.direction,
    required this.message,
  });

  final double? fiveMinuteAverage;
  final double? thirtyMinuteAverage;
  final double? oneHourAverage;
  final String direction;
  final String message;
}

class NeuroTwinSnapshot {
  const NeuroTwinSnapshot({
    required this.latest,
    required this.baseline,
    required this.quality,
    required this.algorithm,
    required this.trend,
    required this.riskScore,
    required this.category,
    required this.detectedDeviations,
    required this.riskReasons,
  });

  final Metrics latest;
  final BaselineProfile baseline;
  final SensorQuality quality;
  final AlgorithmOutput algorithm;
  final TrendResult trend;
  final double riskScore;
  final NeuroTwinRiskCategory category;
  final List<String> detectedDeviations;
  final List<String> riskReasons;
}
