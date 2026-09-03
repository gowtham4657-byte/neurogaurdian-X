import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../metrics/metrics.dart';
import '../metrics/metrics_providers.dart';
import 'history_repository.dart';

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  return HistoryRepository();
});

final historyInitProvider = FutureProvider<void>((ref) async {
  await ref.read(historyRepositoryProvider).init();
});

final historyStreamProvider = StreamProvider<List<Metrics>>((ref) async* {
  await ref.watch(historyInitProvider.future);
  yield* ref.read(historyRepositoryProvider).watch(limit: 200);
});

final historyRecorderProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<Metrics>>(liveMetricsProvider, (prev, next) async {
    final metrics = next.valueOrNull;
    if (metrics == null) return;
    await ref.read(historyInitProvider.future);
    await ref.read(historyRepositoryProvider).add(metrics);
  });
});
