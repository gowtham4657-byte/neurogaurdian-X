import '../metrics/metrics.dart';

class Recommendation {
  const Recommendation({
    required this.title,
    required this.body,
    required this.priority,
  });

  final String title;
  final String body;
  final RecommendationPriority priority;
}

enum RecommendationPriority { calm, watch, urgent }

List<Recommendation> buildRecommendations(Metrics m, RiskScores? risk) {
  final items = <Recommendation>[];
  final stressIndex = risk?.stressIndex ?? m.stressLevel;

  if (m.fallDetected || m.activity == 'Fall detected') {
    items.add(
      const Recommendation(
        title: 'Fall detected',
        body:
            'If no movement is detected for 30 seconds, SOS starts automatically.',
        priority: RecommendationPriority.urgent,
      ),
    );
  }

  if (!m.movementDetected && !m.fallDetected) {
    items.add(
      const Recommendation(
        title: 'No movement',
        body:
            'Movement from the watch will stop the emergency countdown after a fall.',
        priority: RecommendationPriority.watch,
      ),
    );
  }

  if (stressIndex >= 70) {
    items.add(
      Recommendation(
        title: 'AI Health Coach: guided breathing',
        body:
            'Stress pattern is ${stressIndex.toStringAsFixed(0)}. Use a slow 4-7-8 breathing cycle for two minutes and reduce noise/light.',
        priority: RecommendationPriority.watch,
      ),
    );
  }

  if ((m.gsrLevel ?? 0) >= 75) {
    items.add(
      const Recommendation(
        title: 'Burnout warning',
        body:
            'GSR stress is high. Take a quiet break and avoid intense work for a few minutes.',
        priority: RecommendationPriority.watch,
      ),
    );
  }

  if (m.heartRate >= 110) {
    items.add(
      const Recommendation(
        title: 'Reduce intensity',
        body: 'Sit down, hydrate, and check heart rate again in five minutes.',
        priority: RecommendationPriority.watch,
      ),
    );
  }

  if (m.spo2 != null && m.spo2! <= 92) {
    items.add(
      const Recommendation(
        title: 'Low oxygen pattern',
        body:
            'Rest upright and seek medical help if breathlessness, chest pain, or confusion appears.',
        priority: RecommendationPriority.urgent,
      ),
    );
  }

  if (m.temperatureC >= 37.8) {
    items.add(
      const Recommendation(
        title: 'Cool down',
        body: 'Move to a cooler place and monitor temperature.',
        priority: RecommendationPriority.watch,
      ),
    );
  }

  if ((risk?.emergencyProb ?? 0) >= 75) {
    items.add(
      const Recommendation(
        title: 'Prepare SOS',
        body: 'Share location with a guardian if symptoms continue.',
        priority: RecommendationPriority.urgent,
      ),
    );
  }

  if (items.isEmpty) {
    items.add(
      Recommendation(
        title: 'Health score ${risk?.healthScore.toStringAsFixed(0) ?? '--'}',
        body:
            'Your latest sample looks stable. Keep the wearable paired and follow hydration/sleep routine.',
        priority: RecommendationPriority.calm,
      ),
    );
  }

  return items;
}
