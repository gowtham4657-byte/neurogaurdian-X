import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../alerts/alert_event.dart';
import '../alerts/alerts_providers.dart';
import '../metrics/metrics.dart';
import 'history_providers.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historyStreamProvider);
    final alertsAsync = ref.watch(safetyAlertsStreamProvider);

    return DefaultTabController(
      length: 2,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'History',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Clear local records',
                    onPressed: () async {
                      await ref.read(historyInitProvider.future);
                      await ref.read(safetyAlertsInitProvider.future);
                      await ref.read(historyRepositoryProvider).clear();
                      await ref.read(safetyAlertRepositoryProvider).clear();
                    },
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Guardian alert feed plus saved samples from the connected wearable.',
              ),
              const SizedBox(height: 16),
              Card(
                child: TabBar(
                  labelColor: tealColor,
                  unselectedLabelColor: Colors.black54,
                  indicatorColor: tealColor,
                  tabs: const [
                    Tab(icon: Icon(Icons.notifications_active), text: 'Alerts'),
                    Tab(icon: Icon(Icons.monitor_heart), text: 'Samples'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  children: [
                    _AlertFeed(alertsAsync: alertsAsync),
                    _SampleHistory(historyAsync: historyAsync),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertFeed extends StatelessWidget {
  const _AlertFeed({required this.alertsAsync});

  final AsyncValue<List<SafetyAlert>> alertsAsync;

  @override
  Widget build(BuildContext context) {
    return alertsAsync.when(
      data: (list) => list.isEmpty
          ? const Center(
              child: Text('No safety alerts yet. Critical events appear here.'),
            )
          : ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _AlertTile(alert: list[i]),
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Alert feed error: $e')),
    );
  }
}

class _SampleHistory extends StatelessWidget {
  const _SampleHistory({required this.historyAsync});

  final AsyncValue<List<Metrics>> historyAsync;

  @override
  Widget build(BuildContext context) {
    return historyAsync.when(
      data: (list) => list.isEmpty
          ? const Center(child: Text('No samples saved yet.'))
          : ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _HistoryTile(m: list[i]),
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('History error: $e')),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.alert});

  final SafetyAlert alert;

  @override
  Widget build(BuildContext context) {
    final color = _severityColor(alert.severity);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.14),
          foregroundColor: color,
          child: Icon(_iconFor(alert.type)),
        ),
        title: Text(
          alert.title,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          '${alert.message}\n${alert.vitalsLine}'
          '${alert.hasLocation ? ' - GPS saved' : ''}',
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatTime(alert.createdAt),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              _formatDate(alert.createdAt),
              style: const TextStyle(color: Colors.black45, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Color _severityColor(SafetyAlertSeverity severity) {
    switch (severity) {
      case SafetyAlertSeverity.info:
        return tealColor;
      case SafetyAlertSeverity.watch:
        return amberColor;
      case SafetyAlertSeverity.urgent:
        return coralColor;
    }
  }

  IconData _iconFor(String type) {
    if (type.contains('fall')) return Icons.personal_injury_rounded;
    if (type.contains('sos')) return Icons.sos_rounded;
    if (type.contains('battery')) return Icons.battery_alert_rounded;
    return Icons.warning_amber_rounded;
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.m});

  final Metrics m;

  @override
  Widget build(BuildContext context) {
    final heart = m.hasHeartRate ? '${m.heartRate} bpm' : '-- bpm';
    final oxygen = m.hasSpo2 ? '${m.spo2}% SpO2' : '-- SpO2';
    final details = [
      if (m.hasGsr || m.hasHeartRate)
        'Stress ${m.stressLevel.toStringAsFixed(0)}'
      else
        'Stress waiting',
      if (m.hasBodyTemperature)
        '${m.temperatureC.toStringAsFixed(1)} C'
      else
        'temp waiting',
      m.activity,
      if (m.fallDetected) 'fall',
      if (!m.movementDetected) 'no movement',
      if (m.hasWatchGps) 'watch GPS',
      if (m.hasBattery) 'battery ${m.batteryPct}%',
    ];

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: mintColor,
          foregroundColor: tealColor,
          child: const Icon(Icons.monitor_heart_rounded),
        ),
        title: Text('$heart - $oxygen'),
        subtitle: Text(details.join(' - ')),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatTime(m.timestamp),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              _formatDate(m.timestamp),
              style: const TextStyle(color: Colors.black45, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
  }
}
