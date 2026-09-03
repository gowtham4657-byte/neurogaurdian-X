import '../emergency/auto_sos_provider.dart';
import '../metrics/metrics.dart';

class CarePlan {
  const CarePlan({
    required this.severity,
    required this.title,
    required this.summary,
    required this.homeCare,
    required this.exercises,
  });

  final CareSeverity severity;
  final String title;
  final String summary;
  final List<CareSuggestion> homeCare;
  final List<CareSuggestion> exercises;

  bool get isSerious => severity == CareSeverity.serious;
}

class CareSuggestion {
  const CareSuggestion({
    required this.title,
    required this.detail,
    required this.icon,
  });

  final String title;
  final String detail;
  final CareIcon icon;
}

enum CareSeverity {
  minor,
  serious,
}

enum CareIcon {
  breathing,
  hydration,
  cooling,
  rest,
  walk,
  doctor,
  fall,
}

CarePlan buildCarePlan(
    Metrics? metrics, RiskScores? risk, AutoSosState autoSos) {
  if (metrics == null) {
    return const CarePlan(
      severity: CareSeverity.minor,
      title: 'Waiting for live criteria',
      summary: 'Connect the ESP32 watch to generate care suggestions.',
      homeCare: [
        CareSuggestion(
          title: 'Connect wearable',
          detail: 'Keep the ESP32 watch paired and sensors touching the skin.',
          icon: CareIcon.rest,
        ),
      ],
      exercises: [],
    );
  }

  final serious = autoSos.isTriggered ||
      metrics.fallDetected ||
      (metrics.hasHeartRate && metrics.heartRate >= 125) ||
      (metrics.hasSpo2 && metrics.spo2! <= 90) ||
      (metrics.hasBodyTemperature && metrics.temperatureC >= 38.5) ||
      (risk?.emergencyProb ?? 0) >= 75;

  if (serious) {
    return CarePlan(
      severity: CareSeverity.serious,
      title: 'Consult doctor / emergency care',
      summary: autoSos.triggerReason == AutoSosTriggerReason.suddenHeartRateDrop
          ? 'Fall plus sudden heart-rate drop detected. Contact hospital or ambulance immediately.'
          : 'Detected criteria are serious. Avoid exercise and seek medical help.',
      homeCare: const [
        CareSuggestion(
          title: 'Do not exercise',
          detail:
              'Sit or lie safely and avoid exertion until a clinician checks the situation.',
          icon: CareIcon.rest,
        ),
        CareSuggestion(
          title: 'Use emergency support',
          detail:
              'Open SOS, share location, and contact guardian, doctor, or ambulance.',
          icon: CareIcon.doctor,
        ),
      ],
      exercises: const [],
    );
  }

  final homeCare = <CareSuggestion>[];
  final exercises = <CareSuggestion>[];

  if (metrics.stressLevel >= 60 || (risk?.stressIndex ?? 0) >= 60) {
    homeCare.add(
      const CareSuggestion(
        title: 'Reduce stimulation',
        detail:
            'Move to a quiet place, loosen tight clothing, and take slow breaths.',
        icon: CareIcon.rest,
      ),
    );
    exercises.add(
      const CareSuggestion(
        title: '4-7-8 breathing',
        detail:
            'Inhale 4 seconds, hold 7 seconds, exhale 8 seconds. Repeat 4 cycles.',
        icon: CareIcon.breathing,
      ),
    );
  }

  if ((metrics.gsrLevel ?? 0) >= 70) {
    homeCare.add(
      const CareSuggestion(
        title: 'GSR stress reset',
        detail:
            'Pause screens and loud sound for a few minutes. Try relaxed breathing.',
        icon: CareIcon.rest,
      ),
    );
  }

  if (metrics.hasHeartRate && metrics.heartRate >= 100) {
    homeCare.add(
      const CareSuggestion(
        title: 'Rest and hydrate',
        detail:
            'Pause activity, sit comfortably, sip water, and recheck in five minutes.',
        icon: CareIcon.hydration,
      ),
    );
  }

  if (metrics.hasSpo2 && metrics.spo2! <= 94) {
    homeCare.add(
      const CareSuggestion(
        title: 'Oxygen check',
        detail:
            'Sit upright, loosen tight clothing, and recheck SpO2. Seek help if symptoms appear.',
        icon: CareIcon.doctor,
      ),
    );
  }

  if (metrics.hasBodyTemperature && metrics.temperatureC >= 37.2) {
    homeCare.add(
      const CareSuggestion(
        title: 'Cool body gently',
        detail:
            'Use a cool room, light clothing, and fluids. Avoid intense activity.',
        icon: CareIcon.cooling,
      ),
    );
  }

  if (!metrics.fallDetected &&
      metrics.movementDetected &&
      metrics.activity == 'Walking') {
    exercises.add(
      const CareSuggestion(
        title: 'Gentle walk',
        detail:
            'If you feel well, continue light walking and avoid sudden intensity jumps.',
        icon: CareIcon.walk,
      ),
    );
  }

  if (!metrics.movementDetected) {
    homeCare.add(
      const CareSuggestion(
        title: 'Check fall recovery',
        detail:
            'If awake and safe, move slowly. Movement stops the fall SOS countdown.',
        icon: CareIcon.fall,
      ),
    );
  }

  if (homeCare.isEmpty && exercises.isEmpty) {
    if (!metrics.hasCoreVitals) {
      homeCare.add(
        const CareSuggestion(
          title: 'Fix sensor contact',
          detail:
              'Adjust the strap, keep the sensor island touching skin, and wait for valid readings.',
          icon: CareIcon.rest,
        ),
      );
      return CarePlan(
        severity: CareSeverity.minor,
        title: 'Waiting for real sensor data',
        summary:
            'The watch is connected, but vital readings are not valid yet.',
        homeCare: homeCare,
        exercises: exercises,
      );
    }

    homeCare.add(
      const CareSuggestion(
        title: 'Maintain routine',
        detail:
            'Vitals look stable. Continue hydration, sleep hygiene, and regular movement.',
        icon: CareIcon.rest,
      ),
    );
    homeCare.add(
      const CareSuggestion(
        title: 'Hydration reminder',
        detail:
            'Drink water at steady intervals, especially after walking, stress, or heat exposure.',
        icon: CareIcon.hydration,
      ),
    );
    exercises.add(
      const CareSuggestion(
        title: 'Mobility reset',
        detail: 'Try shoulder rolls, neck stretches, and a short relaxed walk.',
        icon: CareIcon.walk,
      ),
    );
  }

  return CarePlan(
    severity: CareSeverity.minor,
    title: 'Minor criteria: home care',
    summary: 'Detected criteria look suitable for gentle care and monitoring.',
    homeCare: homeCare,
    exercises: exercises,
  );
}
