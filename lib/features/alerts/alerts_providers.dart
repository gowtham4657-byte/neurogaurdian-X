import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../emergency/auto_sos_provider.dart';
import '../metrics/metrics.dart';
import '../metrics/metrics_providers.dart';
import 'alert_event.dart';
import 'alerts_repository.dart';

final safetyAlertRepositoryProvider = Provider<SafetyAlertRepository>((ref) {
  return SafetyAlertRepository();
});

final safetyAlertsInitProvider = FutureProvider<void>((ref) async {
  await ref.read(safetyAlertRepositoryProvider).init();
});

final safetyAlertsStreamProvider =
    StreamProvider<List<SafetyAlert>>((ref) async* {
  await ref.watch(safetyAlertsInitProvider.future);
  yield* ref.read(safetyAlertRepositoryProvider).watch(limit: 150);
});

final safetyAlertRecorderProvider = Provider<void>((ref) {
  final lastLoggedAt = <String, DateTime>{};

  Future<void> addAlert(SafetyAlert alert) async {
    await ref.read(safetyAlertsInitProvider.future);
    await ref.read(safetyAlertRepositoryProvider).add(alert);
  }

  bool shouldLog(String key, Duration cooldown) {
    final now = DateTime.now();
    final previous = lastLoggedAt[key];
    if (previous != null && now.difference(previous) < cooldown) {
      return false;
    }
    lastLoggedAt[key] = now;
    return true;
  }

  ref.listen<AsyncValue<Metrics>>(liveMetricsProvider, (previous, next) async {
    final metrics = next.valueOrNull;
    if (metrics == null) return;

    if (metrics.fallDetected &&
        shouldLog('fall', const Duration(seconds: 30))) {
      await addAlert(
        SafetyAlert.fromMetrics(
          type: 'fall',
          title: 'Fall detected',
          message:
              'Wearable detected a fall. The 30-second recovery timer is active.',
          severity: SafetyAlertSeverity.urgent,
          metrics: metrics,
        ),
      );
    }

    if (metrics.hasHeartRate &&
        metrics.heartRate >= 130 &&
        shouldLog('hr_high', const Duration(minutes: 1))) {
      await addAlert(
        SafetyAlert.fromMetrics(
          type: 'threshold',
          title: 'High heart rate',
          message: 'Heart rate crossed 130 bpm.',
          severity: SafetyAlertSeverity.watch,
          metrics: metrics,
        ),
      );
    }

    if (metrics.hasHeartRate &&
        metrics.heartRate <= 45 &&
        shouldLog('hr_low', const Duration(minutes: 1))) {
      await addAlert(
        SafetyAlert.fromMetrics(
          type: 'threshold',
          title: 'Low heart rate',
          message: 'Heart rate dropped below 45 bpm.',
          severity: SafetyAlertSeverity.urgent,
          metrics: metrics,
        ),
      );
    }

    if (metrics.hasSpo2 &&
        metrics.spo2! <= 90 &&
        shouldLog('spo2_low', const Duration(minutes: 1))) {
      await addAlert(
        SafetyAlert.fromMetrics(
          type: 'threshold',
          title: 'Low blood oxygen',
          message: 'SpO2 reading is at or below 90%.',
          severity: SafetyAlertSeverity.urgent,
          metrics: metrics,
        ),
      );
    }

    if (metrics.hasBodyTemperature &&
        metrics.temperatureC >= 38.5 &&
        shouldLog('temp_high', const Duration(minutes: 1))) {
      await addAlert(
        SafetyAlert.fromMetrics(
          type: 'threshold',
          title: 'Fever temperature',
          message: 'Body temperature crossed the fever range.',
          severity: SafetyAlertSeverity.watch,
          metrics: metrics,
        ),
      );
    }

    if ((metrics.hasGsr || metrics.hasHeartRate) &&
        metrics.stressLevel >= 85 &&
        shouldLog('stress_high', const Duration(minutes: 1))) {
      await addAlert(
        SafetyAlert.fromMetrics(
          type: 'threshold',
          title: 'High stress response',
          message: 'Stress index crossed 85/100.',
          severity: SafetyAlertSeverity.watch,
          metrics: metrics,
        ),
      );
    }

    if (metrics.hasBattery &&
        metrics.batteryPct! <= 15 &&
        shouldLog('battery_low', const Duration(minutes: 5))) {
      await addAlert(
        SafetyAlert.fromMetrics(
          type: 'device',
          title: 'Wearable battery low',
          message: 'Battery is ${metrics.batteryPct}%. Charge the watch.',
          severity: SafetyAlertSeverity.watch,
          metrics: metrics,
        ),
      );
    }
  });

  ref.listen<AutoSosState>(autoSosProvider, (previous, next) async {
    final metrics = ref.read(latestMetricsProvider);
    if (metrics == null) return;

    if (next.isCountingDown && previous?.isCountingDown != true) {
      await addAlert(
        SafetyAlert.fromMetrics(
          type: 'fall_timer',
          title: 'Fall timer started',
          message: 'No recovery movement yet. Auto SOS waits 30 seconds.',
          severity: SafetyAlertSeverity.watch,
          metrics: metrics,
        ),
      );
    }

    if (next.isCanceled && next.canceledAt != previous?.canceledAt) {
      await addAlert(
        SafetyAlert.fromMetrics(
          type: 'fall_recovery',
          title: 'Movement detected',
          message: 'The person moved after the fall, so auto SOS stopped.',
          severity: SafetyAlertSeverity.info,
          metrics: metrics,
        ),
      );
    }

    if (next.isTriggered && next.triggeredAt != previous?.triggeredAt) {
      await addAlert(
        SafetyAlert.fromMetrics(
          type: 'sos',
          title: next.triggerReason.title,
          message: next.triggerReason.message,
          severity: SafetyAlertSeverity.urgent,
          metrics: metrics,
        ),
      );
    }
  });
});
