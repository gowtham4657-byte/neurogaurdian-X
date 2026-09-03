import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../history/history_providers.dart';
import 'metrics.dart';
import 'metrics_providers.dart';

final stressInsightProvider = Provider<StressInsight?>((ref) {
  final latest = ref.watch(liveMetricsProvider).valueOrNull;
  if (latest == null) return null;

  final history =
      ref.watch(historyStreamProvider).valueOrNull ?? const <Metrics>[];

  final samples = <Metrics>[];
  samples.add(latest);
  for (final item in history) {
    final isSameAsLatest =
        (item.timestamp.difference(latest.timestamp).inMilliseconds).abs() <
            500;
    if (!isSameAsLatest) samples.add(item);
  }

  if (samples.isEmpty) return null;
  return analyzeStressPattern(samples);
});

final stressAwareRiskScoresProvider = Provider<RiskScores?>((ref) {
  final metrics = ref.watch(liveMetricsProvider).valueOrNull;
  if (metrics == null) return null;

  final baseRisk = calculateRiskScores(metrics);
  final insight = ref.watch(stressInsightProvider);
  if (insight == null) return baseRisk;

  return applyStressInsight(metrics, baseRisk, insight);
});

enum StressPatternLevel { calm, elevated, high, uncertain }

extension StressPatternLevelLabel on StressPatternLevel {
  String get label {
    switch (this) {
      case StressPatternLevel.calm:
        return 'Calm';
      case StressPatternLevel.elevated:
        return 'Elevated';
      case StressPatternLevel.high:
        return 'High';
      case StressPatternLevel.uncertain:
        return 'Uncertain';
    }
  }
}

class StressInsight {
  const StressInsight({
    required this.score,
    required this.rawScore,
    required this.confidence,
    required this.trendDelta,
    required this.level,
    required this.title,
    required this.message,
    required this.baselineHeartRate,
    required this.baselineGsr,
    required this.baselineHrv,
    required this.baselineTemperatureC,
    required this.motionFilterActive,
    required this.signalNotes,
  });

  final double score;
  final double rawScore;
  final double confidence;
  final double trendDelta;
  final StressPatternLevel level;
  final String title;
  final String message;
  final double baselineHeartRate;
  final double baselineGsr;
  final double baselineHrv;
  final double baselineTemperatureC;
  final bool motionFilterActive;
  final List<String> signalNotes;
}

StressInsight analyzeStressPattern(List<Metrics> newestFirst) {
  final samples = newestFirst.toList()
    ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  final latest = samples.first;
  final usable = samples
      .where((m) => !m.fallDetected && (m.hasGsr || m.hasHeartRate || m.hasHrv))
      .take(80)
      .toList();
  final restingBaseline = usable
      .where((m) => _isRestLike(m.activity) && m.movementDetected)
      .skip(1)
      .take(40)
      .toList();
  final fallbackBaseline = usable.skip(1).take(40).toList();
  final baselinePool =
      restingBaseline.length >= 4 ? restingBaseline : fallbackBaseline;

  final baselineHr = _average(
        baselinePool.where((m) => m.hasHeartRate).map((m) => m.heartRate),
      ) ??
      72.0;
  final baselineGsr = _average(
        baselinePool.where((m) => m.hasGsr).map((m) => m.gsrLevel!),
      ) ??
      35.0;
  final baselineHrv = _average(
        baselinePool.where((m) => m.hasHrv).map((m) => m.hrv!),
      ) ??
      45.0;
  final baselineTemp = _average(
        baselinePool
            .where((m) => m.hasBodyTemperature)
            .map((m) => m.temperatureC),
      ) ??
      36.7;

  final motionFilterActive =
      latest.movementDetected && _isActive(latest.activity);
  final gsrLoad = latest.hasGsr
      ? max(
          ((latest.gsrLevel! - baselineGsr) / 45 * 100).clamp(0, 100),
          ((latest.gsrLevel! - 45) / 40 * 100).clamp(0, 100),
        ).toDouble()
      : null;
  final hrvLoad = latest.hasHrv && baselineHrv > 5
      ? ((baselineHrv - latest.hrv!) / baselineHrv * 100)
          .clamp(0, 100)
          .toDouble()
      : null;
  final hrLoad = latest.hasHeartRate
      ? ((latest.heartRate - baselineHr) / 35 * 100).clamp(0, 100).toDouble()
      : null;
  final tempLoad = latest.hasBodyTemperature
      ? ((latest.temperatureC - max(36.8, baselineTemp)) / 1.5 * 100)
          .clamp(0, 100)
          .toDouble()
      : null;

  var rawScore = _weightedAverage([
        _WeightedValue(gsrLoad, 0.38),
        _WeightedValue(hrvLoad, 0.28),
        _WeightedValue(hrLoad, 0.22),
        _WeightedValue(tempLoad, 0.12),
      ]) ??
      latest.stressLevel.clamp(0, 100).toDouble();

  if (motionFilterActive) {
    final cap = latest.activity == 'Running' ? 58.0 : 70.0;
    rawScore = min(rawScore * 0.78, cap);
  }

  final recentStress = _average(
        samples.take(8).map((m) => m.stressLevel.clamp(0, 100)),
      ) ??
      rawScore;
  final olderStress = _average(
        samples.skip(8).take(18).map((m) => m.stressLevel.clamp(0, 100)),
      ) ??
      recentStress;
  final trendDelta = (recentStress - olderStress).toDouble();
  final trendBoost = trendDelta >= 15
      ? 8.0
      : trendDelta >= 8
          ? 4.0
          : 0.0;
  final sustainedBoost = recentStress >= 72
      ? 8.0
      : recentStress >= 62
          ? 4.0
          : 0.0;
  final score =
      (rawScore * 0.72 + recentStress * 0.28 + trendBoost + sustainedBoost)
          .clamp(0, 100)
          .toDouble();

  final channels = [
    latest.hasGsr,
    latest.hasHrv,
    latest.hasHeartRate,
    latest.hasBodyTemperature,
  ].where((v) => v).length;
  var confidence = (channels * 22 + min(20, samples.length * 2)).toDouble();
  if (!latest.hasGsr) confidence -= 12;
  if (!latest.hasHrv) confidence -= 8;
  if (motionFilterActive) confidence -= 10;
  confidence = confidence.clamp(0, 100).toDouble();

  final level = _stressLevel(
    score: score,
    confidence: confidence,
    motionFilterActive: motionFilterActive,
    trendDelta: trendDelta,
  );

  return StressInsight(
    score: score,
    rawScore: rawScore,
    confidence: confidence,
    trendDelta: trendDelta,
    level: level,
    title: _stressTitle(level),
    message: _stressMessage(level, motionFilterActive, trendDelta),
    baselineHeartRate: baselineHr,
    baselineGsr: baselineGsr,
    baselineHrv: baselineHrv,
    baselineTemperatureC: baselineTemp,
    motionFilterActive: motionFilterActive,
    signalNotes: _signalNotes(
      latest: latest,
      baselineHr: baselineHr,
      baselineGsr: baselineGsr,
      baselineHrv: baselineHrv,
      baselineTemp: baselineTemp,
    ),
  );
}

RiskScores applyStressInsight(
  Metrics metrics,
  RiskScores baseRisk,
  StressInsight insight,
) {
  final confidenceWeight = (insight.confidence / 100).clamp(0.25, 0.80);
  final stressIndex = (baseRisk.stressIndex * (1 - confidenceWeight) +
          insight.score * confidenceWeight)
      .clamp(0, 100)
      .toDouble();

  final tempLoad = metrics.hasBodyTemperature
      ? ((metrics.temperatureC - 36.8) / 2.0 * 100).clamp(0, 100).toDouble()
      : 0.0;
  final oxygenLoad = metrics.hasSpo2
      ? ((95 - metrics.spo2!) / 10 * 100).clamp(0, 100).toDouble()
      : 0.0;
  final fallLoad = metrics.fallDetected ? 100.0 : 0.0;

  final emergencyProb = min(
    100.0,
    max(baseRisk.cardiacRisk, fallLoad) * 0.74 +
        stressIndex * 0.18 +
        tempLoad * 0.12 +
        oxygenLoad * 0.18,
  );
  final healthScore = (100 -
          (stressIndex * 0.24 +
              baseRisk.cardiacRisk * 0.33 +
              emergencyProb * 0.28 +
              tempLoad * 0.08 +
              oxygenLoad * 0.07))
      .clamp(0, 100)
      .toDouble();

  final level = metrics.fallDetected ||
          emergencyProb >= 75 ||
          (metrics.hasHeartRate && metrics.heartRate >= 125) ||
          (metrics.hasSpo2 && metrics.spo2! <= 90) ||
          (metrics.hasBodyTemperature && metrics.temperatureC >= 38.5)
      ? RiskLevel.urgent
      : emergencyProb >= 45 || stressIndex >= 65 || baseRisk.cardiacRisk >= 55
          ? RiskLevel.watch
          : RiskLevel.stable;

  final summary = stressIndex >= 70 && level != RiskLevel.urgent
      ? insight.message
      : baseRisk.summary;

  return baseRisk.copyWith(
    stressIndex: stressIndex,
    emergencyProb: emergencyProb,
    healthScore: healthScore,
    level: level,
    summary: summary,
  );
}

StressPatternLevel _stressLevel({
  required double score,
  required double confidence,
  required bool motionFilterActive,
  required double trendDelta,
}) {
  if (confidence < 35) return StressPatternLevel.uncertain;
  if (score >= 82 || (score >= 74 && !motionFilterActive)) {
    return StressPatternLevel.high;
  }
  if (score >= 55 || trendDelta >= 12) return StressPatternLevel.elevated;
  return StressPatternLevel.calm;
}

String _stressTitle(StressPatternLevel level) {
  switch (level) {
    case StressPatternLevel.calm:
      return 'Stress pattern calm';
    case StressPatternLevel.elevated:
      return 'Stress is building';
    case StressPatternLevel.high:
      return 'High stress pattern';
    case StressPatternLevel.uncertain:
      return 'Stress reading uncertain';
  }
}

String _stressMessage(
  StressPatternLevel level,
  bool motionFilterActive,
  double trendDelta,
) {
  if (motionFilterActive) {
    return 'Movement filter is active, so exercise is separated from stress before raising risk.';
  }
  if (trendDelta >= 15) {
    return 'Stress has risen compared with the recent baseline. Rest and recheck soon.';
  }
  switch (level) {
    case StressPatternLevel.calm:
      return 'Skin response, heart rate, HRV, and temperature are near the personal baseline.';
    case StressPatternLevel.elevated:
      return 'Stress signs are elevated. Try breathing, hydration, and a quiet break.';
    case StressPatternLevel.high:
      return 'Sustained high stress pattern detected. Stop intense activity and monitor symptoms.';
    case StressPatternLevel.uncertain:
      return 'Not enough clean sensor data yet. Tighten the watch and collect more samples.';
  }
}

List<String> _signalNotes({
  required Metrics latest,
  required double baselineHr,
  required double baselineGsr,
  required double baselineHrv,
  required double baselineTemp,
}) {
  final notes = <String>[];
  if (latest.hasGsr) {
    notes.add(
        'GSR ${latest.gsrLevel!.toStringAsFixed(0)} vs baseline ${baselineGsr.toStringAsFixed(0)}');
  }
  if (latest.hasHrv) {
    notes.add(
        'HRV ${latest.hrv!.toStringAsFixed(0)} ms vs baseline ${baselineHrv.toStringAsFixed(0)} ms');
  }
  if (latest.hasHeartRate) {
    notes.add(
        'HR ${latest.heartRate} bpm vs baseline ${baselineHr.toStringAsFixed(0)} bpm');
  }
  if (latest.hasBodyTemperature) {
    notes.add(
        'Temp ${latest.temperatureC.toStringAsFixed(1)} C vs baseline ${baselineTemp.toStringAsFixed(1)} C');
  }
  if (notes.isEmpty) {
    notes.add('Waiting for GSR, HR, HRV, or temperature signals.');
  }
  return notes.take(4).toList();
}

bool _isRestLike(String activity) {
  final value = activity.toLowerCase();
  return value.contains('rest') ||
      value.contains('sleep') ||
      value.contains('still') ||
      value.contains('no movement');
}

bool _isActive(String activity) {
  final value = activity.toLowerCase();
  return value.contains('walk') ||
      value.contains('run') ||
      value.contains('active');
}

double? _average(Iterable<num> values) {
  final list = values.toList();
  if (list.isEmpty) return null;
  return list.reduce((a, b) => a + b).toDouble() / list.length;
}

double? _weightedAverage(List<_WeightedValue> values) {
  var total = 0.0;
  var weight = 0.0;
  for (final item in values) {
    final value = item.value;
    if (value == null) continue;
    total += value * item.weight;
    weight += item.weight;
  }
  return weight == 0 ? null : total / weight;
}

class _WeightedValue {
  const _WeightedValue(this.value, this.weight);

  final double? value;
  final double weight;
}
