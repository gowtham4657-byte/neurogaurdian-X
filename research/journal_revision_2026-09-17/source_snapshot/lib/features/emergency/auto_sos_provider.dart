import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../metrics/metrics.dart';
import '../metrics/metrics_providers.dart';

final autoSosProvider = StateNotifierProvider<AutoSosController, AutoSosState>(
  (ref) {
    final controller = AutoSosController();
    ref.listen<AsyncValue<Metrics>>(liveMetricsProvider, (previous, next) {
      final metrics = next.valueOrNull;
      if (metrics != null) controller.handleMetrics(metrics);
    });
    return controller;
  },
);

class AutoSosState {
  const AutoSosState({
    required this.status,
    this.secondsRemaining = 0,
    this.fallStartedAt,
    this.triggeredAt,
    this.canceledAt,
    this.triggerReason = AutoSosTriggerReason.none,
  });

  const AutoSosState.idle()
      : status = AutoSosStatus.idle,
        secondsRemaining = 0,
        fallStartedAt = null,
        triggeredAt = null,
        canceledAt = null,
        triggerReason = AutoSosTriggerReason.none;

  final AutoSosStatus status;
  final int secondsRemaining;
  final DateTime? fallStartedAt;
  final DateTime? triggeredAt;
  final DateTime? canceledAt;
  final AutoSosTriggerReason triggerReason;

  bool get isCountingDown => status == AutoSosStatus.countingDown;
  bool get isTriggered => status == AutoSosStatus.triggered;
  bool get isCanceled => status == AutoSosStatus.canceled;
  bool get isVisible => isCountingDown || isTriggered || isCanceled;
}

enum AutoSosStatus {
  idle,
  countingDown,
  triggered,
  canceled,
}

enum AutoSosTriggerReason {
  none,
  noMovement,
  suddenHeartRateDrop,
}

extension AutoSosTriggerReasonText on AutoSosTriggerReason {
  String get title {
    switch (this) {
      case AutoSosTriggerReason.none:
        return 'Manual SOS';
      case AutoSosTriggerReason.noMovement:
        return 'Fall timer: no movement';
      case AutoSosTriggerReason.suddenHeartRateDrop:
        return 'Fall plus sudden heart-rate drop';
    }
  }

  String get message {
    switch (this) {
      case AutoSosTriggerReason.none:
        return 'I may need help.';
      case AutoSosTriggerReason.noMovement:
        return 'Patient may be unconscious: fall detected with no movement for 30 seconds. Send ambulance support to current location.';
      case AutoSosTriggerReason.suddenHeartRateDrop:
        return 'Patient may be unconscious: fall detected with sudden heart-rate drop. Send ambulance support to current location.';
    }
  }
}

class AutoSosController extends StateNotifier<AutoSosState> {
  AutoSosController({Duration? triggerDelay})
      : _triggerDelay = triggerDelay ?? AutoSosController.triggerDelay,
        super(const AutoSosState.idle()) {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  static const triggerDelay = Duration(seconds: 30);
  static const suddenHeartRateDropBpm = 20;

  final Duration _triggerDelay;
  Timer? _timer;
  DateTime? _fallStartedAt;
  bool _noMovementAfterFall = false;
  Metrics? _previousMetrics;

  void handleMetrics(Metrics metrics) {
    final previous = _previousMetrics;
    _previousMetrics = metrics;
    final fallSignal = metrics.fallDetected ||
        metrics.activity == 'Fall detected' ||
        metrics.activity == 'Critical fall';
    final criticalFallSignal = metrics.activity == 'Critical fall';
    final noMovement =
        !metrics.movementDetected || metrics.activity == 'No movement';
    final suddenHeartRateDrop = previous != null &&
        previous.hasHeartRate &&
        metrics.hasHeartRate &&
        previous.heartRate - metrics.heartRate >= suddenHeartRateDropBpm;

    if (criticalFallSignal ||
        ((fallSignal || _fallStartedAt != null) && suddenHeartRateDrop)) {
      _trigger(
        AutoSosTriggerReason.suddenHeartRateDrop,
        startedAt: _fallStartedAt ?? DateTime.now(),
      );
      return;
    }

    if (fallSignal) {
      _fallStartedAt ??= DateTime.now();
      // The fall impact itself is movement, so do not cancel on a fall packet.
      // A later non-fall movement packet means the patient recovered/moved.
      _noMovementAfterFall = true;
      _tick();
      return;
    }

    if (_fallStartedAt != null && noMovement) {
      _noMovementAfterFall = true;
      _tick();
      return;
    }

    if (metrics.movementDetected && _fallStartedAt != null) {
      _stopBecauseMovement();
    } else if (metrics.movementDetected) {
      reset();
    }
  }

  void reset() {
    _fallStartedAt = null;
    _noMovementAfterFall = false;
    state = const AutoSosState.idle();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    final canceledAt = state.canceledAt;
    if (state.isCanceled && canceledAt != null) {
      if (DateTime.now().difference(canceledAt) >= const Duration(seconds: 6)) {
        reset();
      }
      return;
    }

    final startedAt = _fallStartedAt;
    if (startedAt == null || !_noMovementAfterFall) return;
    if (state.isTriggered) return;

    final elapsed = DateTime.now().difference(startedAt);
    final remaining = _triggerDelay - elapsed;
    if (remaining <= Duration.zero) {
      _trigger(AutoSosTriggerReason.noMovement, startedAt: startedAt);
      return;
    }

    state = AutoSosState(
      status: AutoSosStatus.countingDown,
      secondsRemaining: remaining.inSeconds + 1,
      fallStartedAt: startedAt,
      triggerReason: AutoSosTriggerReason.noMovement,
    );
  }

  void _trigger(
    AutoSosTriggerReason reason, {
    required DateTime startedAt,
  }) {
    _fallStartedAt = null;
    _noMovementAfterFall = false;
    state = AutoSosState(
      status: AutoSosStatus.triggered,
      fallStartedAt: startedAt,
      triggeredAt: DateTime.now(),
      triggerReason: reason,
    );
  }

  void _stopBecauseMovement() {
    final startedAt = _fallStartedAt;
    _fallStartedAt = null;
    _noMovementAfterFall = false;
    state = AutoSosState(
      status: AutoSosStatus.canceled,
      fallStartedAt: startedAt,
      canceledAt: DateTime.now(),
    );
  }
}
