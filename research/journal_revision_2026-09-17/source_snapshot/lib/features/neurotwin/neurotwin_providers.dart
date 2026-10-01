import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../history/history_providers.dart';
import '../metrics/metrics_providers.dart';
import 'neurotwin_engine.dart';
import 'neurotwin_models.dart';

final neuroTwinEngineProvider = Provider<NeuroTwinEngine>((ref) {
  return const NeuroTwinEngine();
});

final neuroTwinSnapshotProvider = Provider<NeuroTwinSnapshot?>((ref) {
  final latest = ref.watch(liveMetricsProvider).valueOrNull;
  final history = ref.watch(historyStreamProvider).valueOrNull ?? const [];
  return ref.read(neuroTwinEngineProvider).build(
        latest: latest,
        history: history,
      );
});
