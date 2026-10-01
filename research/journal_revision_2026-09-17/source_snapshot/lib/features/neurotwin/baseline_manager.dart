import 'dart:math' as math;

import '../metrics/metrics.dart';
import 'neurotwin_models.dart';

class BaselineManager {
  const BaselineManager();

  BaselineProfile buildProfile({
    required Metrics latest,
    required List<Metrics> history,
  }) {
    final context = _activityContext(latest.activity);
    final candidates = history
        .where((m) => _shouldUseForBaseline(m, context))
        .take(120)
        .toList();

    return BaselineProfile(
      activityContext: context,
      metrics: [
        _metric(
          key: 'heartRate',
          label: 'Heart Rate',
          unit: 'bpm',
          current: latest.hasHeartRate ? latest.heartRate.toDouble() : null,
          values: candidates
              .where((m) => m.hasHeartRate)
              .map((m) => m.heartRate.toDouble()),
          minStd: 3,
        ),
        _metric(
          key: 'spo2',
          label: 'SpO2',
          unit: '%',
          current: latest.hasSpo2 ? latest.spo2!.toDouble() : null,
          values: candidates.where((m) => m.hasSpo2).map((m) => m.spo2!),
          minStd: 0.8,
        ),
        _metric(
          key: 'hrv',
          label: 'HRV',
          unit: 'ms',
          current: latest.hasHrv ? latest.hrv : null,
          values: candidates.where((m) => m.hasHrv).map((m) => m.hrv!),
          minStd: 5,
        ),
        _metric(
          key: 'gsr',
          label: 'GSR',
          unit: 'score',
          current: latest.hasGsr ? latest.gsrLevel : null,
          values: candidates.where((m) => m.hasGsr).map((m) => m.gsrLevel!),
          minStd: 4,
        ),
        _metric(
          key: 'temperature',
          label: 'Temperature',
          unit: 'C',
          current: latest.hasBodyTemperature ? latest.temperatureC : null,
          values: candidates
              .where((m) => m.hasBodyTemperature)
              .map((m) => m.temperatureC),
          minStd: 0.2,
        ),
        _metric(
          key: 'ecg',
          label: 'ECG',
          unit: 'mV',
          current: latest.hasEcg ? latest.ecgMv : null,
          values: candidates.where((m) => m.hasEcg).map((m) => m.ecgMv!),
          minStd: 0.08,
        ),
      ],
      validSampleCount: candidates.length,
      lastUpdated: candidates.isEmpty ? null : candidates.first.timestamp,
    );
  }

  bool shouldUpdateBaseline(Metrics metrics) {
    return _shouldUseForBaseline(metrics, _activityContext(metrics.activity));
  }

  bool _shouldUseForBaseline(Metrics m, String context) {
    if (m.fallDetected || !m.movementDetected) return false;
    if (m.overallSignalQuality < 0.45) return false;
    if (m.watchFit == false || m.skinContact == false) return false;
    if (!_sameContext(_activityContext(m.activity), context)) return false;
    if (m.hasHeartRate && (m.heartRate < 35 || m.heartRate > 180)) {
      return false;
    }
    if (m.hasBodyTemperature && (m.temperatureC < 32 || m.temperatureC > 41)) {
      return false;
    }
    return m.hasHeartRate || m.hasGsr || m.hasHrv || m.hasBodyTemperature;
  }

  bool _sameContext(String left, String right) {
    if (left == right) return true;
    if (left == 'resting' && right == 'sleeping') return true;
    if (left == 'sleeping' && right == 'resting') return true;
    return false;
  }

  BaselineMetric _metric({
    required String key,
    required String label,
    required String unit,
    required double? current,
    required Iterable<num> values,
    required double minStd,
  }) {
    final list = values.map((v) => v.toDouble()).toList();
    final mean = _mean(list);
    final std = _std(list, mean);
    return BaselineMetric(
      key: key,
      label: label,
      unit: unit,
      current: current,
      mean: mean,
      stdDeviation: std == null ? null : math.max(std, minStd),
      sampleCount: list.length,
    );
  }

  double? _mean(List<double> values) {
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  double? _std(List<double> values, double? mean) {
    if (values.length < 2 || mean == null) return null;
    final variance =
        values.map((v) => math.pow(v - mean, 2)).reduce((a, b) => a + b) /
            (values.length - 1);
    return math.sqrt(variance);
  }

  String _activityContext(String activity) {
    final value = activity.toLowerCase();
    if (value.contains('sleep')) return 'sleeping';
    if (value.contains('run')) return 'running';
    if (value.contains('walk') || value.contains('active')) return 'walking';
    if (value.contains('fall') || value.contains('movement')) return 'recovery';
    return 'resting';
  }
}
