import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../history/history_providers.dart';
import '../metrics/metrics.dart';
import '../metrics/metrics_providers.dart';
import '../metrics/stress_analysis.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historyStreamProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Analytics', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            const Text('Rolling view from the latest wearable samples.'),
            const SizedBox(height: 16),
            Expanded(
              child: historyAsync.when(
                data: (items) => items.length < 2
                    ? const Center(
                        child: Text('Collect a few samples to unlock trends.'),
                      )
                    : ListView(
                        children: [
                          _SummaryStrip(items: items),
                          const SizedBox(height: 12),
                          _StressIntelligenceCard(items: items),
                          const SizedBox(height: 12),
                          _TrendCard(
                            title: 'Heart rate',
                            unit: 'bpm',
                            color: coralColor,
                            items: items,
                            valueOf: (m) =>
                                m.hasHeartRate ? m.heartRate.toDouble() : null,
                            minY: 40,
                            maxY: 150,
                          ),
                          const SizedBox(height: 12),
                          _TrendCard(
                            title: 'Blood oxygen',
                            unit: '% SpO2',
                            color: const Color(0xFF2E74B5),
                            items: items,
                            valueOf: (m) =>
                                m.hasSpo2 ? m.spo2!.toDouble() : null,
                            minY: 85,
                            maxY: 100,
                          ),
                          const SizedBox(height: 12),
                          _TrendCard(
                            title: 'Stress index',
                            unit: 'score',
                            color: amberColor,
                            items: items,
                            valueOf: (m) => m.stressLevel,
                            minY: 0,
                            maxY: 100,
                          ),
                          const SizedBox(height: 12),
                          _TrendCard(
                            title: 'GSR skin response',
                            unit: 'score',
                            color: const Color(0xFF7A5A00),
                            items: items,
                            valueOf: (m) => m.gsrLevel,
                            minY: 0,
                            maxY: 100,
                          ),
                          const SizedBox(height: 12),
                          _TrendCard(
                            title: 'Temperature',
                            unit: 'C',
                            color: tealColor,
                            items: items,
                            valueOf: (m) =>
                                m.hasBodyTemperature ? m.temperatureC : null,
                            minY: 35,
                            maxY: 40,
                          ),
                          const SizedBox(height: 12),
                          _TrendCard(
                            title: 'ECG amplitude',
                            unit: 'mV',
                            color: const Color(0xFF5D6B99),
                            items: items,
                            valueOf: (m) => m.ecgMv,
                            minY: 0,
                            maxY: 2,
                          ),
                        ],
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('History error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StressIntelligenceCard extends StatelessWidget {
  const _StressIntelligenceCard({required this.items});

  final List<Metrics> items;

  @override
  Widget build(BuildContext context) {
    final insight = analyzeStressPattern(items);
    final color = switch (insight.level) {
      StressPatternLevel.calm => tealColor,
      StressPatternLevel.elevated => amberColor,
      StressPatternLevel.high => coralColor,
      StressPatternLevel.uncertain => Colors.black45,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.14),
                  foregroundColor: color,
                  child: const Icon(Icons.psychology_alt_rounded),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Adaptive stress intelligence',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(insight.message),
                    ],
                  ),
                ),
                Text(
                  insight.score.toStringAsFixed(0),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _TinyPill(
                  label: 'Level',
                  value: insight.level.label,
                ),
                _TinyPill(
                  label: 'Confidence',
                  value: '${insight.confidence.toStringAsFixed(0)}%',
                ),
                _TinyPill(
                  label: 'Trend',
                  value:
                      '${insight.trendDelta >= 0 ? '+' : ''}${insight.trendDelta.toStringAsFixed(0)}',
                ),
                _TinyPill(
                  label: 'Baseline',
                  value:
                      '${insight.baselineHeartRate.toStringAsFixed(0)} bpm / ${insight.baselineGsr.toStringAsFixed(0)} GSR',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TinyPill extends StatelessWidget {
  const _TinyPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF2F6F4),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Text(
          '$label: $value',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.items});

  final List<Metrics> items;

  @override
  Widget build(BuildContext context) {
    final avgHr = _averageOptional(
      items.where((m) => m.hasHeartRate).map((m) => m.heartRate.toDouble()),
    );
    final avgStress = _averageOptional(
      items.where((m) => m.hasGsr || m.hasHeartRate).map((m) => m.stressLevel),
    );
    final avgSpo2 = _averageOptional(
      items.where((m) => m.hasSpo2).map((m) => m.spo2!.toDouble()),
    );
    final latest = items.first;
    final health = calculateRiskScores(latest).healthScore;

    return Row(
      children: [
        Expanded(
          child: _MiniStat(
            label: 'Avg HR',
            value: avgHr == null ? '--' : avgHr.toStringAsFixed(0),
            unit: 'bpm',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniStat(
            label: 'Avg stress',
            value: avgStress == null ? '--' : avgStress.toStringAsFixed(0),
            unit: 'score',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniStat(
            label: 'Avg SpO2',
            value: avgSpo2 == null ? '--' : avgSpo2.toStringAsFixed(0),
            unit: '%',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniStat(
            label: 'Health',
            value: health.toStringAsFixed(0),
            unit: _formatTime(latest.timestamp),
          ),
        ),
      ],
    );
  }

  double? _averageOptional(Iterable<double?> values) {
    final list = values.whereType<double>().toList();
    if (list.isEmpty) return null;
    return list.reduce((a, b) => a + b) / list.length;
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(unit, style: const TextStyle(color: Colors.black45)),
          ],
        ),
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({
    required this.title,
    required this.unit,
    required this.color,
    required this.items,
    required this.valueOf,
    required this.minY,
    required this.maxY,
  });

  final String title;
  final String unit;
  final Color color;
  final List<Metrics> items;
  final double? Function(Metrics metrics) valueOf;
  final double minY;
  final double maxY;

  @override
  Widget build(BuildContext context) {
    final ordered = items.take(40).toList().reversed.toList();
    final spots = <FlSpot>[];
    for (var i = 0; i < ordered.length; i++) {
      final value = valueOf(ordered[i]);
      if (value != null) spots.add(FlSpot(i.toDouble(), value));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
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
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: spots.length < 2
                  ? const Center(
                      child: Text('Waiting for enough wearable samples.'),
                    )
                  : LineChart(
                      LineChartData(
                        minY: minY,
                        maxY: maxY,
                        gridData: FlGridData(
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (_) => const FlLine(
                              color: Color(0xFFE3E8E5), strokeWidth: 1),
                        ),
                        titlesData: const FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 36,
                            ),
                          ),
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            barWidth: 3,
                            color: color,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: color.withOpacity(0.08),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
