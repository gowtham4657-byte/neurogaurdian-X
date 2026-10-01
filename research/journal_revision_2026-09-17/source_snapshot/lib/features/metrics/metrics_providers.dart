import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ble/ble_repository.dart';
import 'metrics.dart';

final bleRepositoryProvider = Provider<BLERepository>((ref) {
  final repo = BLERepository();
  ref.onDispose(repo.dispose);
  return repo;
});

final liveMetricsProvider = StreamProvider<Metrics>((ref) {
  final repo = ref.watch(bleRepositoryProvider);
  return repo.metricsStream;
});

final wearableConnectionProvider = StreamProvider<String>((ref) {
  final repo = ref.watch(bleRepositoryProvider);
  return repo.connectionStatus;
});

final discoveredWearablesProvider = StreamProvider<List<WearableDevice>>((ref) {
  final repo = ref.watch(bleRepositoryProvider);
  return repo.discoveredDevices;
});

final latestMetricsProvider = Provider<Metrics?>((ref) {
  return ref.watch(liveMetricsProvider).valueOrNull;
});

final riskScoresProvider = Provider<RiskScores?>((ref) {
  final metrics = ref.watch(liveMetricsProvider).valueOrNull;
  return metrics == null ? null : calculateRiskScores(metrics);
});

RiskScores calculateRiskScores(Metrics m) {
  if (!m.hasCoreVitals && !m.fallDetected && m.movementDetected) {
    return const RiskScores(
      stressIndex: 0,
      cardiacRisk: 0,
      emergencyProb: 0,
      healthScore: 0,
      level: RiskLevel.watch,
      summary:
          'Waiting for valid watch sensor contact. Risk detection is paused.',
    );
  }

  final ppgUsable = (m.ppgQuality ?? 1) >= 0.45 &&
      m.watchFit != false &&
      m.skinContact != false;
  final ecgUsable = (m.ecgQuality ?? 1) >= 0.45;
  final gsrUsable = (m.gsrQuality ?? 1) >= 0.45;
  final tempUsable = (m.temperatureQuality ?? 1) >= 0.45;
  final heartRateLoad = m.hasHeartRate && ppgUsable
      ? ((m.heartRate - 65) / 70 * 100).clamp(0, 100)
      : 0;
  final stressLoad = gsrUsable || ppgUsable ? m.stressLevel.clamp(0, 100) : 0;
  final tempLoad = m.hasBodyTemperature && tempUsable
      ? ((m.temperatureC - 36.8) / 2.0 * 100).clamp(0, 100)
      : 0;
  final oxygenLoad =
      m.hasSpo2 && ppgUsable ? ((95 - m.spo2!) / 10 * 100).clamp(0, 100) : 0.0;
  final gsrLoad = gsrUsable ? (m.gsrLevel ?? m.stressLevel).clamp(0, 100) : 0.0;
  final hrvLoad =
      m.hasHrv && ppgUsable ? (100 - (m.hrv! / 70 * 100)).clamp(0, 100) : 35.0;
  final motionLoad = m.activity == 'Running' ? 18.0 : 0.0;
  final fallLoad = m.fallDetected ? 100.0 : 0.0;
  final ecgLoad =
      m.hasEcg && ecgUsable ? (m.ecgMv!.abs() * 18).clamp(0, 18) : 0.0;

  final cardiacRisk = min(
    100.0,
    heartRateLoad * 0.39 +
        tempLoad * 0.15 +
        hrvLoad * 0.20 +
        oxygenLoad * 0.17 +
        ecgLoad * 0.09,
  );
  final stressIndex = min(
    100.0,
    stressLoad * 0.45 + gsrLoad * 0.28 + hrvLoad * 0.17 + motionLoad,
  );
  final emergencyProb = min(
    100.0,
    max(max(stressIndex, cardiacRisk), fallLoad) * 0.75 +
        tempLoad * 0.12 +
        oxygenLoad * 0.18,
  );
  final healthScore = (100 -
          (stressIndex * 0.25 +
              cardiacRisk * 0.32 +
              emergencyProb * 0.28 +
              tempLoad * 0.08 +
              oxygenLoad * 0.07))
      .clamp(0, 100);

  final level = m.fallDetected ||
          emergencyProb >= 75 ||
          (m.hasHeartRate && m.heartRate >= 125) ||
          (m.hasSpo2 && m.spo2! <= 90) ||
          (m.hasBodyTemperature && m.temperatureC >= 38.5)
      ? RiskLevel.urgent
      : emergencyProb >= 45 || stressIndex >= 65 || cardiacRisk >= 55
          ? RiskLevel.watch
          : RiskLevel.stable;

  return RiskScores(
    stressIndex: stressIndex.toDouble(),
    cardiacRisk: cardiacRisk.toDouble(),
    emergencyProb: emergencyProb.toDouble(),
    healthScore: healthScore.toDouble(),
    level: level,
    summary: _riskSummary(m, level),
  );
}

String _riskSummary(Metrics metrics, RiskLevel level) {
  if (metrics.fallDetected) {
    return 'Fall detected. Watching movement before auto SOS.';
  }
  if (!metrics.movementDetected) {
    return 'No movement signal. Waiting for recovery movement.';
  }
  if (!metrics.hasCoreVitals) {
    return 'Waiting for valid sensor contact from the watch.';
  }
  if (metrics.hasSpo2 && metrics.spo2! <= 90) {
    return 'Low SpO2 pattern detected. Prepare medical support.';
  }
  if (metrics.gsrLevel != null && metrics.gsrLevel! >= 75) {
    return 'GSR stress response is high. Reduce stimulation and monitor.';
  }

  switch (level) {
    case RiskLevel.stable:
      return 'Vitals are inside the normal band.';
    case RiskLevel.watch:
      return 'A change is building. Slow down and recheck soon.';
    case RiskLevel.urgent:
      return 'Critical pattern detected. Prepare SOS support.';
  }
}
