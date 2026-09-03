import 'package:flutter_test/flutter_test.dart';
import 'package:neuroguardian_app/features/emergency/auto_sos_provider.dart';
import 'package:neuroguardian_app/features/metrics/metrics.dart';

void main() {
  Metrics sample({
    String activity = 'Resting',
    bool fallDetected = false,
    bool movementDetected = true,
    int heartRate = 82,
  }) {
    return Metrics(
      timestamp: DateTime.now(),
      heartRate: heartRate,
      stressLevel: 40,
      temperatureC: 36.7,
      activity: activity,
      fallDetected: fallDetected,
      movementDetected: movementDetected,
    );
  }

  test('fall impact starts countdown and later movement cancels it', () {
    final controller = AutoSosController();
    addTearDown(controller.dispose);

    controller.handleMetrics(
      sample(
        activity: 'Fall detected',
        fallDetected: true,
        movementDetected: true,
      ),
    );

    expect(controller.state.status, AutoSosStatus.countingDown);

    controller.handleMetrics(sample(activity: 'Walking'));

    expect(controller.state.status, AutoSosStatus.canceled);
  });

  test('fall with no recovery movement triggers SOS after countdown', () async {
    final controller = AutoSosController(
      triggerDelay: const Duration(milliseconds: 10),
    );
    addTearDown(controller.dispose);

    controller.handleMetrics(
      sample(
        activity: 'Fall detected',
        fallDetected: true,
        movementDetected: false,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    controller.handleMetrics(
      sample(activity: 'No movement', movementDetected: false),
    );

    expect(controller.state.status, AutoSosStatus.triggered);
    expect(
      controller.state.triggerReason,
      AutoSosTriggerReason.noMovement,
    );
  });

  test('critical fall signal triggers SOS immediately', () {
    final controller = AutoSosController();
    addTearDown(controller.dispose);

    controller.handleMetrics(
      sample(
        activity: 'Critical fall',
        fallDetected: true,
        movementDetected: false,
        heartRate: 60,
      ),
    );

    expect(controller.state.status, AutoSosStatus.triggered);
    expect(
      controller.state.triggerReason,
      AutoSosTriggerReason.suddenHeartRateDrop,
    );
  });
}
