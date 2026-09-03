import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_mode.dart';
import '../../core/theme.dart';
import '../emergency/auto_sos_provider.dart';
import '../knowledge/condition_database.dart';
import '../metrics/metrics.dart';
import '../metrics/metrics_providers.dart';
import '../metrics/stress_analysis.dart';
import '../recommendations/recommendation_engine.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(liveMetricsProvider);
    final risk = ref.watch(stressAwareRiskScoresProvider);
    final stressInsight = ref.watch(stressInsightProvider);
    final autoSos = ref.watch(autoSosProvider);

    void cancelAutoSos() {
      ref.read(autoSosProvider.notifier).reset();
      unawaited(ref.read(bleRepositoryProvider).sendCommand('BUZZER_OFF'));
    }

    return SafeArea(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF6FBF8), Color(0xFFFFF7EE), Color(0xFFE9F5F3)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _Header(
                showDemoTools: AppMode.enableDemoTools,
                onDemo: () => ref.read(bleRepositoryProvider).startDemo(),
                onFallDemo: () =>
                    ref.read(bleRepositoryProvider).startFallDemo(),
                onMoveDemo: () =>
                    ref.read(bleRepositoryProvider).startFallRecoveryDemo(),
                onCriticalFallDemo: () =>
                    ref.read(bleRepositoryProvider).startCriticalFallDemo(),
                metrics: metricsAsync.valueOrNull,
                risk: risk,
              ),
            ),
            const SliverToBoxAdapter(child: _TrustStrip()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              sliver: metricsAsync.when(
                data: (metrics) => SliverList.list(
                  children: [
                    _VitalsGrid(metrics: metrics),
                    const SizedBox(height: 12),
                    _BodyTemperatureMeter(metrics: metrics),
                    const SizedBox(height: 12),
                    _WearableSignalsCard(metrics: metrics),
                    const SizedBox(height: 12),
                    _StressInsightCard(insight: stressInsight),
                    if (!autoSos.isVisible) const SizedBox(height: 12),
                    if (autoSos.isVisible) ...[
                      const SizedBox(height: 12),
                      _AutoSosBanner(
                        state: autoSos,
                        onCancel: cancelAutoSos,
                      ),
                    ],
                    const SizedBox(height: 12),
                    _RiskPanel(risk: risk),
                    const SizedBox(height: 12),
                    _DetectionDatabaseSection(
                      results: detectionDatabase
                          .map((record) => record.evaluate(metrics, risk))
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    _Recommendations(
                      metrics: metrics,
                      risk: risk,
                    ),
                  ],
                ),
                loading: () => SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(
                    showDemoTools: AppMode.enableDemoTools,
                    onDemo: () => ref.read(bleRepositoryProvider).startDemo(),
                    onFallDemo: () =>
                        ref.read(bleRepositoryProvider).startFallDemo(),
                    onMoveDemo: () =>
                        ref.read(bleRepositoryProvider).startFallRecoveryDemo(),
                    onCriticalFallDemo: () =>
                        ref.read(bleRepositoryProvider).startCriticalFallDemo(),
                  ),
                ),
                error: (e, _) => SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text('Signal error: $e')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.showDemoTools,
    required this.onDemo,
    required this.onFallDemo,
    required this.onMoveDemo,
    required this.onCriticalFallDemo,
    required this.metrics,
    required this.risk,
  });

  final bool showDemoTools;
  final VoidCallback onDemo;
  final VoidCallback onFallDemo;
  final VoidCallback onMoveDemo;
  final VoidCallback onCriticalFallDemo;
  final Metrics? metrics;
  final RiskScores? risk;

  @override
  Widget build(BuildContext context) {
    final level = risk?.level ?? RiskLevel.stable;
    final color = _riskColor(level);
    final currentMetrics = metrics;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFBF2), Color(0xFFE1F2EC), Color(0xFFFFD8CD)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22007C7A),
            blurRadius: 34,
            offset: Offset(0, 20),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned(
            right: -34,
            top: -42,
            child: _GlowOrb(size: 138, color: Color(0x22007C7A)),
          ),
          const Positioned(
            left: -46,
            bottom: -58,
            child: _GlowOrb(size: 148, color: Color(0x22E35B50)),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _HeroBadge(),
                          SizedBox(height: 10),
                          Text(
                            'NeuroGuardian X',
                            style: TextStyle(
                              color: inkColor,
                              fontSize: 30,
                              height: 0.98,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Fall, vitals, and SOS protection for families and communities.',
                            style: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _StatusPill(label: level.label, color: color),
                  ],
                ),
                const SizedBox(height: 18),
                if (showDemoTools) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _DemoChip(
                        label: 'Live demo',
                        icon: Icons.play_arrow_rounded,
                        onPressed: onDemo,
                      ),
                      _DemoChip(
                        label: 'Fall test',
                        icon: Icons.personal_injury_rounded,
                        onPressed: onFallDemo,
                      ),
                      _DemoChip(
                        label: 'Movement cancel',
                        icon: Icons.directions_run_rounded,
                        onPressed: onMoveDemo,
                      ),
                      _DemoChip(
                        label: 'Critical fall',
                        icon: Icons.emergency_share_rounded,
                        onPressed: onCriticalFallDemo,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                ],
                Row(
                  children: [
                    Expanded(
                      child: _HeroMetric(
                        label: 'Signal',
                        value: currentMetrics == null
                            ? 'Waiting'
                            : currentMetrics.sensorQualityLabel,
                        detail: currentMetrics == null
                            ? 'Connect watch'
                            : 'Sample ${_time(currentMetrics.timestamp)}',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _HeroMetric(
                        label: 'AI detection',
                        value: risk == null ? 'Ready' : risk!.level.label,
                        detail: risk?.summary ?? 'Monitoring bands',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _riskColor(RiskLevel level) {
    switch (level) {
      case RiskLevel.stable:
        return const Color(0xFF58D68D);
      case RiskLevel.watch:
        return amberColor;
      case RiskLevel.urgent:
        return coralColor;
    }
  }

  String _time(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.74),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_rounded, size: 15, color: tealColor),
            SizedBox(width: 6),
            Text(
              'Community safety mode',
              style: TextStyle(
                color: inkColor,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoChip extends StatelessWidget {
  const _DemoChip({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: inkColor),
      label: Text(label),
      labelStyle: const TextStyle(
        color: inkColor,
        fontWeight: FontWeight.w900,
      ),
      backgroundColor: Colors.white.withOpacity(0.74),
      side: BorderSide(color: Colors.black.withOpacity(0.08)),
      onPressed: onPressed,
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.label,
    required this.value,
    required this.detail,
  });

  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: inkColor,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.black87, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _TrustStrip extends StatelessWidget {
  const _TrustStrip();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        children: const [
          _TrustCard(
            icon: Icons.timer_rounded,
            title: '30s fall timer',
            detail: 'Movement cancels SOS',
          ),
          _TrustCard(
            icon: Icons.local_hospital_rounded,
            title: 'Ambulance route',
            detail: 'Critical fall uses hospital contact',
          ),
          _TrustCard(
            icon: Icons.lock_rounded,
            title: 'Local records',
            detail: 'History and contacts stay on device',
          ),
        ],
      ),
    );
  }
}

class _TrustCard extends StatelessWidget {
  const _TrustCard({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: mintColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: tealColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: const TextStyle(
            color: inkColor,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.showDemoTools,
    required this.onDemo,
    required this.onFallDemo,
    required this.onMoveDemo,
    required this.onCriticalFallDemo,
  });

  final bool showDemoTools;
  final VoidCallback onDemo;
  final VoidCallback onFallDemo;
  final VoidCallback onMoveDemo;
  final VoidCallback onCriticalFallDemo;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.monitor_heart_outlined,
                size: 54,
                color: tealColor,
              ),
              const SizedBox(height: 12),
              Text(
                'No live signal yet',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                showDemoTools
                    ? 'Developer demo tools are enabled. Use them only for testing.'
                    : 'Connect the ESP32-S3 wearable from the Device tab to start live real BLE data.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              if (showDemoTools)
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: onDemo,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Start demo'),
                    ),
                    OutlinedButton.icon(
                      onPressed: onFallDemo,
                      icon: const Icon(Icons.personal_injury_rounded),
                      label: const Text('Fall demo'),
                    ),
                    OutlinedButton.icon(
                      onPressed: onMoveDemo,
                      icon: const Icon(Icons.directions_run_rounded),
                      label: const Text('Movement stops SOS'),
                    ),
                    OutlinedButton.icon(
                      onPressed: onCriticalFallDemo,
                      icon: const Icon(Icons.emergency_share_rounded),
                      label: const Text('Critical fall'),
                    ),
                  ],
                )
              else
                FilledButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.bluetooth_searching_rounded),
                  label: const Text('Use Device tab to connect watch'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VitalsGrid extends StatelessWidget {
  const _VitalsGrid({required this.metrics});

  final Metrics metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _VitalTile(
              width: tileWidth,
              title: 'Heart rate',
              value: metrics.hasHeartRate ? '${metrics.heartRate}' : '--',
              unit: 'bpm',
              icon: Icons.favorite_rounded,
              color: coralColor,
            ),
            _VitalTile(
              width: tileWidth,
              title: 'Blood oxygen',
              value: metrics.hasSpo2 ? metrics.spo2.toString() : '--',
              unit: '% SpO2',
              icon: Icons.bloodtype_rounded,
              color: const Color(0xFF2E74B5),
            ),
            _VitalTile(
              width: tileWidth,
              title: 'Stress',
              value: metrics.hasGsr || metrics.hasHeartRate
                  ? metrics.stressLevel.toStringAsFixed(0)
                  : '--',
              unit: 'index',
              icon: Icons.self_improvement_rounded,
              color: amberColor,
            ),
            _VitalTile(
              width: tileWidth,
              title: 'Temp',
              value: metrics.hasBodyTemperature
                  ? metrics.temperatureC.toStringAsFixed(1)
                  : '--',
              unit: 'C',
              icon: Icons.thermostat_rounded,
              color: tealColor,
            ),
            _VitalTile(
              width: tileWidth,
              title: 'GSR',
              value: metrics.gsrLevel?.toStringAsFixed(0) ?? '--',
              unit: 'skin stress',
              icon: Icons.sensors_rounded,
              color: const Color(0xFF7A5A00),
            ),
            _VitalTile(
              width: tileWidth,
              title: 'Activity',
              value: metrics.activity,
              unit: metrics.movementDetected
                  ? 'Movement on'
                  : metrics.fallDetected
                      ? 'Fall signal'
                      : 'No movement',
              icon: Icons.directions_walk_rounded,
              color: const Color(0xFF5D6B99),
            ),
          ],
        );
      },
    );
  }
}

class _VitalTile extends StatelessWidget {
  const _VitalTile({
    required this.width,
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  final double width;
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                alignment: Alignment.centerLeft,
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                unit,
                style: const TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WearableSignalsCard extends StatelessWidget {
  const _WearableSignalsCard({required this.metrics});

  final Metrics metrics;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: mintColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.watch_rounded, color: tealColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Wearable sensor signals',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Text(
                        'MAX30102, GSR, AD8232 ECG, MPU6050, GPS, battery',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SignalPill(
                  label: 'Quality',
                  value: metrics.sensorQualityLabel,
                ),
                _SignalPill(
                  label: 'HRV',
                  value: !metrics.hasHrv
                      ? 'waiting'
                      : '${metrics.hrv!.toStringAsFixed(0)} ms',
                ),
                _SignalPill(
                  label: 'GSR',
                  value: !metrics.hasGsr
                      ? 'waiting'
                      : metrics.gsrLevel!.toStringAsFixed(0),
                ),
                _SignalPill(
                  label: 'ECG',
                  value: !metrics.hasEcg
                      ? 'waiting'
                      : '${metrics.ecgMv!.toStringAsFixed(2)} mV',
                ),
                _SignalPill(
                  label: 'Motion',
                  value: metrics.movementDetected ? 'moving' : 'still',
                ),
                _SignalPill(
                  label: 'GPS',
                  value: !metrics.hasWatchGps ? 'phone fallback' : 'watch fix',
                ),
                _SignalPill(
                  label: 'Battery',
                  value: !metrics.hasBattery
                      ? 'not wired'
                      : '${metrics.batteryPct}%',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StressInsightCard extends StatelessWidget {
  const _StressInsightCard({required this.insight});

  final StressInsight? insight;

  @override
  Widget build(BuildContext context) {
    final data = insight;
    final color = data == null
        ? Colors.black45
        : switch (data.level) {
            StressPatternLevel.calm => tealColor,
            StressPatternLevel.elevated => amberColor,
            StressPatternLevel.high => coralColor,
            StressPatternLevel.uncertain => Colors.black45,
          };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: data == null
            ? const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.psychology_alt_rounded),
                title: Text(
                  'Adaptive stress detection',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  'Waiting for watch data to build a personal baseline.',
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 68,
                        height: 68,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CircularProgressIndicator(
                              value: data.score / 100,
                              strokeWidth: 8,
                              backgroundColor: color.withOpacity(0.12),
                              valueColor: AlwaysStoppedAnimation<Color>(color),
                            ),
                            Center(
                              child: Text(
                                data.score.toStringAsFixed(0),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(data.message),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _SignalPill(
                        label: 'Confidence',
                        value: '${data.confidence.toStringAsFixed(0)}%',
                      ),
                      _SignalPill(
                        label: 'Trend',
                        value:
                            '${data.trendDelta >= 0 ? '+' : ''}${data.trendDelta.toStringAsFixed(0)}',
                      ),
                      _SignalPill(
                        label: 'Motion filter',
                        value: data.motionFilterActive ? 'active' : 'quiet',
                      ),
                      _SignalPill(
                        label: 'Baseline HR',
                        value:
                            '${data.baselineHeartRate.toStringAsFixed(0)} bpm',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final note in data.signalNotes)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_rounded,
                              size: 16, color: color),
                          const SizedBox(width: 8),
                          Expanded(child: Text(note)),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _SignalPill extends StatelessWidget {
  const _SignalPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF2F6F4),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: RichText(
          text: TextSpan(
            style: const TextStyle(color: inkColor, fontSize: 12),
            children: [
              TextSpan(
                text: '$label: ',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              TextSpan(text: value),
            ],
          ),
        ),
      ),
    );
  }
}

class _BodyTemperatureMeter extends StatelessWidget {
  const _BodyTemperatureMeter({required this.metrics});

  final Metrics metrics;

  @override
  Widget build(BuildContext context) {
    final temperatureC = metrics.temperatureC;
    final hasReading = metrics.hasBodyTemperature;
    final status =
        hasReading ? _statusFor(temperatureC) : 'Waiting for skin sensor';
    final color = hasReading ? _colorFor(temperatureC) : Colors.black45;
    final percent =
        hasReading ? ((temperatureC - 34.0) / 7.0).clamp(0.0, 1.0) : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.device_thermostat_rounded, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Body temperature meter',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        status,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    hasReading
                        ? '${temperatureC.toStringAsFixed(1)} C'
                        : '-- C',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final markerLeft = (constraints.maxWidth - 14) * percent;
                return SizedBox(
                  height: 34,
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: Row(
                          children: const [
                            Expanded(
                              flex: 31,
                              child: ColoredBox(color: Color(0xFF7CCDBB)),
                            ),
                            Expanded(
                              flex: 6,
                              child: ColoredBox(color: Color(0xFFFFCB66)),
                            ),
                            Expanded(
                              flex: 16,
                              child: ColoredBox(color: Color(0xFFFF8A65)),
                            ),
                            Expanded(
                              flex: 17,
                              child: ColoredBox(color: Color(0xFFD74B4B)),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        left: markerLeft,
                        child: Container(
                          width: 14,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: inkColor, width: 2),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x33000000),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _TempBandLabel(label: 'Low', value: '34'),
                _TempBandLabel(label: 'Normal', value: '36-37.2'),
                _TempBandLabel(label: 'Fever', value: '37.8+'),
                _TempBandLabel(label: 'High', value: '39.4+'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _statusFor(double c) {
    if (c < 35.0) return 'Low body temperature';
    if (c <= 37.2) return 'Normal human body range';
    if (c < 37.8) return 'Elevated temperature';
    if (c < 39.4) return 'Fever range';
    return 'High fever range';
  }

  Color _colorFor(double c) {
    if (c < 35.0) return const Color(0xFF5D6B99);
    if (c <= 37.2) return tealColor;
    if (c < 37.8) return amberColor;
    if (c < 39.4) return const Color(0xFFFF7043);
    return coralColor;
  }
}

class _TempBandLabel extends StatelessWidget {
  const _TempBandLabel({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.black54,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _AutoSosBanner extends StatelessWidget {
  const _AutoSosBanner({required this.state, required this.onCancel});

  final AutoSosState state;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final triggered = state.isTriggered;
    final canceled = state.isCanceled;
    return Card(
      color: triggered
          ? const Color(0xFFFFE7E7)
          : canceled
              ? const Color(0xFFE7F7EF)
              : const Color(0xFFFFF4DC),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              triggered
                  ? Icons.sos_rounded
                  : canceled
                      ? Icons.directions_run_rounded
                      : Icons.timer_outlined,
              color: triggered
                  ? coralColor
                  : canceled
                      ? tealColor
                      : amberColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    triggered
                        ? state.triggerReason.title
                        : canceled
                            ? 'Movement detected: timer stopped'
                            : 'Fall timer: ${state.secondsRemaining}s to ambulance',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    triggered
                        ? state.triggerReason ==
                                AutoSosTriggerReason.suddenHeartRateDrop
                            ? 'Fall paired with a sudden heart-rate drop. Ambulance SOS opens immediately.'
                            : 'No movement continued for 30 seconds. Hospital/ambulance SOS opens.'
                        : canceled
                            ? 'The watch detected movement, so auto SOS was canceled.'
                            : 'Movement will stop the timer. No movement opens hospital/ambulance SOS.',
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: canceled ? tealColor : inkColor,
                foregroundColor: Colors.white,
              ),
              onPressed: onCancel,
              icon: const Icon(Icons.check_circle_rounded),
              label: const Text('I AM OKAY'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetectionDatabaseSection extends StatelessWidget {
  const _DetectionDatabaseSection({required this.results});

  final List<DetectionResult> results;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Detection databases',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const Icon(Icons.storage_rounded, color: tealColor),
          ],
        ),
        const SizedBox(height: 8),
        for (final result in results) _DetectionDatabaseCard(result: result),
      ],
    );
  }
}

class _DetectionDatabaseCard extends StatelessWidget {
  const _DetectionDatabaseCard({required this.result});

  final DetectionResult result;

  @override
  Widget build(BuildContext context) {
    final color = _severityColor(result.record.severity);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_severityIcon(result.record.severity), color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.record.database,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        result.record.title,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
                _DatabaseStatusPill(
                  active: result.active,
                  severity: result.record.severity,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(result.record.summary),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: result.confidence / 100,
                minHeight: 8,
                color: color,
                backgroundColor: color.withOpacity(0.12),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              result.record.trigger,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final sensor in result.record.sensors)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(sensor),
                    backgroundColor: mintColor,
                    side: BorderSide.none,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _severityColor(DetectionSeverity severity) {
    switch (severity) {
      case DetectionSeverity.stable:
        return tealColor;
      case DetectionSeverity.watch:
        return amberColor;
      case DetectionSeverity.urgent:
        return coralColor;
    }
  }

  IconData _severityIcon(DetectionSeverity severity) {
    switch (severity) {
      case DetectionSeverity.stable:
        return Icons.sensors_rounded;
      case DetectionSeverity.watch:
        return Icons.psychology_alt_rounded;
      case DetectionSeverity.urgent:
        return Icons.monitor_heart_rounded;
    }
  }
}

class _DatabaseStatusPill extends StatelessWidget {
  const _DatabaseStatusPill({required this.active, required this.severity});

  final bool active;
  final DetectionSeverity severity;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? switch (severity) {
            DetectionSeverity.stable => tealColor,
            DetectionSeverity.watch => amberColor,
            DetectionSeverity.urgent => coralColor,
          }
        : Colors.black45;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          active ? 'ACTIVE' : 'READY',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _RiskPanel extends StatelessWidget {
  const _RiskPanel({required this.risk});

  final RiskScores? risk;

  @override
  Widget build(BuildContext context) {
    final scores = risk ??
        const RiskScores(
          stressIndex: 0,
          cardiacRisk: 0,
          emergencyProb: 0,
          healthScore: 0,
          level: RiskLevel.stable,
          summary: 'Waiting for data.',
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI risk detection',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _RiskMeter(
                    label: 'Health',
                    value: scores.healthScore,
                    color: tealColor,
                  ),
                ),
                Expanded(
                  child: _RiskMeter(
                    label: 'Stress',
                    value: scores.stressIndex,
                    color: amberColor,
                  ),
                ),
                Expanded(
                  child: _RiskMeter(
                    label: 'Cardiac',
                    value: scores.cardiacRisk,
                    color: coralColor,
                  ),
                ),
                Expanded(
                  child: _RiskMeter(
                    label: 'SOS',
                    value: scores.emergencyProb,
                    color: tealColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RiskMeter extends StatelessWidget {
  const _RiskMeter({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 58,
          height: 58,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: value / 100,
                strokeWidth: 7,
                backgroundColor: color.withOpacity(0.12),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
              Center(
                child: Text(
                  value.toStringAsFixed(0),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }
}

class _Recommendations extends StatelessWidget {
  const _Recommendations({required this.metrics, required this.risk});

  final Metrics metrics;
  final RiskScores? risk;

  @override
  Widget build(BuildContext context) {
    final recommendations = buildRecommendations(metrics, risk);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recommendations', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final item in recommendations) _RecommendationCard(item: item),
      ],
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.item});

  final Recommendation item;

  @override
  Widget build(BuildContext context) {
    final color = switch (item.priority) {
      RecommendationPriority.calm => tealColor,
      RecommendationPriority.watch => amberColor,
      RecommendationPriority.urgent => coralColor,
    };

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.14),
          foregroundColor: color,
          child: Icon(
            item.priority == RecommendationPriority.urgent
                ? Icons.sos_rounded
                : Icons.check_rounded,
          ),
        ),
        title: Text(
          item.title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(item.body),
      ),
    );
  }
}
