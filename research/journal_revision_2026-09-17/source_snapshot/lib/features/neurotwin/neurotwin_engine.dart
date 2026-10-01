import 'dart:math' as math;

import '../metrics/metrics.dart';
import '../metrics/metrics_providers.dart';
import '../metrics/stress_analysis.dart';
import 'baseline_manager.dart';
import 'neurotwin_models.dart';
import 'signal_quality_manager.dart';
import 'trend_analyzer.dart';

class NeuroTwinEngine {
  const NeuroTwinEngine({
    this.baselineManager = const BaselineManager(),
    this.signalQualityManager = const SignalQualityManager(),
    this.trendAnalyzer = const TrendAnalyzer(),
  });

  final BaselineManager baselineManager;
  final SignalQualityManager signalQualityManager;
  final TrendAnalyzer trendAnalyzer;

  NeuroTwinSnapshot? build({
    required Metrics? latest,
    required List<Metrics> history,
  }) {
    if (latest == null) return null;

    final newestFirst = <Metrics>[latest, ...history]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final baseline = baselineManager.buildProfile(
      latest: latest,
      history: newestFirst.skip(1).toList(),
    );
    final quality = signalQualityManager.evaluate(latest);
    final baseRisk = calculateRiskScores(latest);
    final stressInsight =
        newestFirst.length >= 3 ? analyzeStressPattern(newestFirst) : null;
    final stressScore =
        (stressInsight?.score ?? baseRisk.stressIndex).clamp(0, 100).toDouble();
    final ecgAnomaly = _ecgAnomalyProbability(latest, baseline, quality);
    final fallProbability = _fallProbability(latest);
    final trend = trendAnalyzer.analyze(latest: latest, history: history);
    final deviations = _detectedDeviations(latest, baseline);
    final reasons = _riskReasons(
      latest: latest,
      baseline: baseline,
      quality: quality,
      baseRisk: baseRisk,
      stressScore: stressScore,
      ecgAnomaly: ecgAnomaly,
      fallProbability: fallProbability,
      deviations: deviations,
    );
    var riskScore = _riskScore(
      latest: latest,
      baseRisk: baseRisk,
      quality: quality,
      stressScore: stressScore,
      ecgAnomaly: ecgAnomaly,
      fallProbability: fallProbability,
    );
    if (!baseline.ready && !latest.fallDetected) {
      riskScore = math.min(riskScore, 72);
    }

    return NeuroTwinSnapshot(
      latest: latest,
      baseline: baseline,
      quality: quality,
      algorithm: AlgorithmOutput(
        stressScore: stressScore,
        ecgAnomalyProbability: ecgAnomaly,
        fallProbability: fallProbability,
        activity: latest.activity,
      ),
      trend: trend,
      riskScore: riskScore,
      category: _category(riskScore),
      detectedDeviations: deviations.isEmpty
          ? const ['No important deviation from the available baseline.']
          : deviations,
      riskReasons: reasons,
    );
  }

  double _riskScore({
    required Metrics latest,
    required RiskScores baseRisk,
    required SensorQuality quality,
    required double stressScore,
    required double ecgAnomaly,
    required double fallProbability,
  }) {
    final oxygenLoad = latest.hasSpo2
        ? ((95 - latest.spo2!) / 10 * 100).clamp(0, 100).toDouble()
        : 0.0;
    final tempLoad = latest.hasBodyTemperature
        ? ((latest.temperatureC - 36.8) / 2 * 100).clamp(0, 100).toDouble()
        : 0.0;
    var score = stressScore * 0.18 +
        baseRisk.cardiacRisk * 0.22 +
        ecgAnomaly * 0.18 +
        fallProbability * 0.26 +
        oxygenLoad * 0.10 +
        tempLoad * 0.06;

    if (!quality.reliableForRisk && !latest.fallDetected) {
      score *= 0.72;
    }
    if (latest.fallDetected && !latest.movementDetected) {
      score = math.max(score, 82);
    }
    if (latest.activity == 'Critical fall') {
      score = math.max(score, 92);
    }
    return score.clamp(0, 100).toDouble();
  }

  double _ecgAnomalyProbability(
    Metrics latest,
    BaselineProfile baseline,
    SensorQuality quality,
  ) {
    if (!latest.hasEcg || quality.ecg < 0.45) return 0;
    final ecgMetric = baseline.metrics.firstWhere(
      (m) => m.key == 'ecg',
      orElse: () => const BaselineMetric(
        key: 'ecg',
        label: 'ECG',
        unit: 'mV',
        current: null,
        mean: null,
        stdDeviation: null,
        sampleCount: 0,
      ),
    );
    final absZ = ecgMetric.zScore?.abs() ?? 0;
    final amplitudeLoad =
        ((latest.ecgMv!.abs() - 0.8) / 1.2 * 100).clamp(0, 100).toDouble();
    final zLoad = absZ >= 3
        ? 80.0
        : absZ >= 2
            ? 55.0
            : absZ >= 1
                ? 24.0
                : 8.0;
    final hrvLoad = latest.hasHrv
        ? ((35 - latest.hrv!) / 25 * 100).clamp(0, 100).toDouble()
        : 18.0;
    final restingBoost = _isResting(latest.activity) ? 8.0 : 0.0;
    return (zLoad * 0.42 + amplitudeLoad * 0.34 + hrvLoad * 0.16 + restingBoost)
        .clamp(0, 100)
        .toDouble();
  }

  double _fallProbability(Metrics latest) {
    if (latest.activity == 'Critical fall') return 98;
    if (latest.fallDetected && !latest.movementDetected) return 92;
    if (latest.fallDetected) return 78;
    final accel = latest.accelerationMagnitudeG;
    final gyroPeak = [
      latest.gyroXDps?.abs() ?? 0,
      latest.gyroYDps?.abs() ?? 0,
      latest.gyroZDps?.abs() ?? 0,
    ].reduce(math.max);
    final accelLoad = accel == null
        ? 0.0
        : ((accel - 1.4) / 1.4 * 100).clamp(0, 100).toDouble();
    final gyroLoad = ((gyroPeak - 90) / 160 * 100).clamp(0, 100).toDouble();
    final stillnessLoad = latest.movementDetected ? 0.0 : 38.0;
    return (accelLoad * 0.44 + gyroLoad * 0.26 + stillnessLoad)
        .clamp(0, 100)
        .toDouble();
  }

  List<String> _detectedDeviations(Metrics latest, BaselineProfile baseline) {
    final deviations = <String>[];
    for (final metric in baseline.metrics) {
      final z = metric.zScore;
      if (z == null || z.abs() < 1.5) continue;
      final direction = z > 0 ? 'above' : 'below';
      deviations.add(
        '${metric.label} is $direction baseline by ${z.abs().toStringAsFixed(1)} z-score.',
      );
    }
    if (latest.fallDetected) deviations.add('Fall pattern is active.');
    if (!latest.movementDetected) {
      deviations.add('No movement signal is active.');
    }
    return deviations.take(6).toList();
  }

  List<String> _riskReasons({
    required Metrics latest,
    required BaselineProfile baseline,
    required SensorQuality quality,
    required RiskScores baseRisk,
    required double stressScore,
    required double ecgAnomaly,
    required double fallProbability,
    required List<String> deviations,
  }) {
    final reasons = <String>[];
    if (!baseline.ready) {
      reasons.add(
          'Personal baseline is still learning, so warnings stay conservative.');
    }
    if (!quality.reliableForRisk) {
      reasons.add(
          'Signal quality is limited; unreliable sensors are reduced in risk scoring.');
    }
    if (_isActive(latest.activity) && latest.hasHeartRate) {
      reasons.add(
          'Activity context is active, so exercise heart-rate rise is filtered.');
    }
    if (stressScore >= 65) {
      reasons.add(
          'Stress pattern is elevated using GSR, HR, HRV, and temperature.');
    }
    if (ecgAnomaly >= 55) {
      reasons.add(
          'Unusual ECG pattern probability is elevated; this is not a diagnosis.');
    }
    if (baseRisk.cardiacRisk >= 55) {
      reasons.add(
          'Cardiac wellness score is raised by HR, HRV, SpO2, or temperature.');
    }
    if (fallProbability >= 70) {
      reasons.add('Fall probability is high from movement/fall signals.');
    }
    if (deviations.isNotEmpty) {
      reasons.add('Current readings differ from the personal baseline.');
    }
    if (reasons.isEmpty) {
      reasons
          .add('Available signals are close to the current personal baseline.');
    }
    return reasons.take(7).toList();
  }

  NeuroTwinRiskCategory _category(double score) {
    if (score >= 80) return NeuroTwinRiskCategory.criticalReview;
    if (score >= 60) return NeuroTwinRiskCategory.warning;
    if (score >= 30) return NeuroTwinRiskCategory.observe;
    return NeuroTwinRiskCategory.normal;
  }

  bool _isActive(String activity) {
    final value = activity.toLowerCase();
    return value.contains('walk') ||
        value.contains('run') ||
        value.contains('active');
  }

  bool _isResting(String activity) {
    final value = activity.toLowerCase();
    return value.contains('rest') ||
        value.contains('sleep') ||
        value.contains('still') ||
        value.contains('no movement');
  }
}
