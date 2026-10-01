import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../metrics/metrics.dart';
import '../metrics/metrics_providers.dart';
import '../settings/user_settings.dart';
import 'neurotwin_models.dart';
import 'neurotwin_providers.dart';

class NeuroTwinScreen extends ConsumerStatefulWidget {
  const NeuroTwinScreen({super.key, this.onOpenSos});

  final VoidCallback? onOpenSos;

  @override
  ConsumerState<NeuroTwinScreen> createState() => _NeuroTwinScreenState();
}

class _NeuroTwinScreenState extends ConsumerState<NeuroTwinScreen> {
  String? _actionMessage;

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(neuroTwinSnapshotProvider);
    final connection = ref.watch(wearableConnectionProvider).valueOrNull ??
        'Wearable not connected';
    final settings = ref.watch(userSettingsProvider).valueOrNull;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('NeuroTwin', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          const Text(
            'Personalized wellness baseline, signal quality, and risk reasons from real wearable data.',
          ),
          const SizedBox(height: 16),
          if (snapshot == null)
            _WaitingCard(connection: connection)
          else ...[
            _HeroCard(snapshot: snapshot, connection: connection),
            const SizedBox(height: 12),
            _ActionCard(
              snapshot: snapshot,
              settings: settings,
              onRunSensorCheck: _runSensorCheck,
              onCalibrateBaseline: _calibrateBaseline,
              onCheckFit: _checkWatchFit,
              onTestSosSafely: _testSosSafely,
              onUpdateContacts: widget.onOpenSos,
              onViewReasons: _viewReasons,
            ),
            if (_actionMessage != null) ...[
              const SizedBox(height: 8),
              _InfoStrip(message: _actionMessage!),
            ],
            const SizedBox(height: 12),
            _ReadinessCard(snapshot: snapshot, settings: settings),
            const SizedBox(height: 12),
            _RawSensorCard(metrics: snapshot.latest),
            const SizedBox(height: 12),
            _SignalQualityCard(quality: snapshot.quality),
            const SizedBox(height: 12),
            _BaselineCard(profile: snapshot.baseline),
            const SizedBox(height: 12),
            _AlgorithmCard(output: snapshot.algorithm),
            const SizedBox(height: 12),
            _NeuroTwinOutputCard(snapshot: snapshot),
            const SizedBox(height: 12),
            _TrendCard(trend: snapshot.trend),
            const SizedBox(height: 12),
            const _SafetyLanguageCard(),
          ],
        ],
      ),
    );
  }

  void _runSensorCheck(NeuroTwinSnapshot snapshot) {
    setState(() {
      _actionMessage = snapshot.quality.reliableForRisk
          ? 'Sensor check complete: readings are usable for wellness risk estimation.'
          : 'Sensor check complete: ${snapshot.quality.notes.first}';
    });
  }

  void _calibrateBaseline(NeuroTwinSnapshot snapshot) {
    setState(() {
      _actionMessage = snapshot.baseline.ready
          ? 'Baseline is ready for ${snapshot.baseline.activityContext}. It will keep adapting slowly from clean samples.'
          : 'Baseline is learning: ${(snapshot.baseline.completion * 100).toStringAsFixed(0)}% complete. Keep wearing the band normally.';
    });
  }

  void _checkWatchFit(NeuroTwinSnapshot snapshot) {
    setState(() {
      _actionMessage = snapshot.quality.watchFit
          ? 'Watch fit looks usable. Keep the sensor side flat on skin.'
          : 'Watch fit needs attention. Tighten the band and clean the sensor contact area.';
    });
  }

  void _testSosSafely() {
    setState(() {
      _actionMessage =
          'Safe SOS check: open the SOS tab and confirm guardian, GPS, and backend readiness before sending a real alert.';
    });
  }

  void _viewReasons(NeuroTwinSnapshot snapshot) {
    setState(() {
      _actionMessage = snapshot.riskReasons.join(' ');
    });
  }
}

class _WaitingCard extends StatelessWidget {
  const _WaitingCard({required this.connection});

  final String connection;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(
              backgroundColor: mintColor,
              foregroundColor: tealColor,
              child: Icon(Icons.sensors_rounded),
            ),
            const SizedBox(height: 14),
            Text(
              'Waiting for real watch data',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(connection),
            const SizedBox(height: 10),
            const Text(
              'Connect the ESP32 wearable to unlock NeuroTwin baseline, quality, and risk explanations.',
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.snapshot, required this.connection});

  final NeuroTwinSnapshot snapshot;
  final String connection;

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(snapshot.category);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.96), const Color(0xFF102A2A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.22),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.hub_rounded, color: Colors.white, size: 34),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    connection,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${snapshot.riskScore.toStringAsFixed(0)}/100',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              snapshot.category.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              snapshot.riskReasons.first,
              style: const TextStyle(color: Colors.white, height: 1.35),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _HeroPill('Baseline', snapshot.baseline.statusLabel),
                _HeroPill('Quality', snapshot.quality.label),
                _HeroPill('Activity', snapshot.algorithm.activity),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          '$label: $value',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.snapshot,
    required this.settings,
    required this.onRunSensorCheck,
    required this.onCalibrateBaseline,
    required this.onCheckFit,
    required this.onTestSosSafely,
    required this.onUpdateContacts,
    required this.onViewReasons,
  });

  final NeuroTwinSnapshot snapshot;
  final UserSettings? settings;
  final ValueChanged<NeuroTwinSnapshot> onRunSensorCheck;
  final ValueChanged<NeuroTwinSnapshot> onCalibrateBaseline;
  final ValueChanged<NeuroTwinSnapshot> onCheckFit;
  final VoidCallback onTestSosSafely;
  final VoidCallback? onUpdateContacts;
  final ValueChanged<NeuroTwinSnapshot> onViewReasons;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Real-user actions',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ActionChipButton(
                  icon: Icons.fact_check_outlined,
                  label: 'Run Sensor Check',
                  onPressed: () => onRunSensorCheck(snapshot),
                ),
                _ActionChipButton(
                  icon: Icons.tune_rounded,
                  label: 'Calibrate Baseline',
                  onPressed: () => onCalibrateBaseline(snapshot),
                ),
                _ActionChipButton(
                  icon: Icons.watch_rounded,
                  label: 'Check Watch Fit',
                  onPressed: () => onCheckFit(snapshot),
                ),
                _ActionChipButton(
                  icon: Icons.verified_user_outlined,
                  label: 'Test SOS Safely',
                  onPressed: onTestSosSafely,
                ),
                _ActionChipButton(
                  icon: Icons.contact_phone_outlined,
                  label: 'Update Contacts',
                  onPressed: onUpdateContacts,
                ),
                _ActionChipButton(
                  icon: Icons.psychology_alt_outlined,
                  label: 'View Risk Reasons',
                  onPressed: () => onViewReasons(snapshot),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionChipButton extends StatelessWidget {
  const _ActionChipButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _InfoStrip extends StatelessWidget {
  const _InfoStrip({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: mintColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _ReadinessCard extends StatelessWidget {
  const _ReadinessCard({required this.snapshot, required this.settings});

  final NeuroTwinSnapshot snapshot;
  final UserSettings? settings;

  @override
  Widget build(BuildContext context) {
    final guardianReady = _hasRealPhone(settings?.guardianPhone ?? '');
    final backendReady =
        (settings?.emergencyBackendUrl.trim().isNotEmpty ?? false) &&
            (settings?.emergencyBackendToken.trim().isNotEmpty ?? false);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Health check readiness',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _ReadinessRow(
              label: 'Wearable sensors',
              value: snapshot.latest.sensorQualityLabel,
              good: snapshot.quality.overall >= 0.55,
            ),
            _ReadinessRow(
              label: 'Watch fit',
              value: snapshot.quality.watchFit
                  ? 'Usable contact'
                  : 'Needs adjustment',
              good: snapshot.quality.watchFit,
            ),
            _ReadinessRow(
              label: 'Baseline',
              value:
                  '${snapshot.baseline.statusLabel} (${(snapshot.baseline.completion * 100).toStringAsFixed(0)}%)',
              good: snapshot.baseline.ready,
            ),
            _ReadinessRow(
              label: 'Guardian contact',
              value: guardianReady ? 'Saved' : 'Missing',
              good: guardianReady,
            ),
            _ReadinessRow(
              label: 'SOS backend',
              value: backendReady ? 'Cloud configured' : 'Needs setup',
              good: backendReady,
            ),
          ],
        ),
      ),
    );
  }

  static bool _hasRealPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length >= 10 && !phone.contains('X');
  }
}

class _ReadinessRow extends StatelessWidget {
  const _ReadinessRow({
    required this.label,
    required this.value,
    required this.good,
  });

  final String label;
  final String value;
  final bool good;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            good ? Icons.check_circle_rounded : Icons.info_rounded,
            color: good ? tealColor : amberColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Text(value, textAlign: TextAlign.right),
        ],
      ),
    );
  }
}

class _RawSensorCard extends StatelessWidget {
  const _RawSensorCard({required this.metrics});

  final Metrics metrics;

  @override
  Widget build(BuildContext context) {
    final gps = metrics.hasWatchGps
        ? '${metrics.latitude!.toStringAsFixed(5)}, ${metrics.longitude!.toStringAsFixed(5)}'
        : 'Phone fallback';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Raw sensor values',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _SensorGrid(
              values: [
                _SensorValue(
                    'Heart Rate',
                    metrics.hasHeartRate ? '${metrics.heartRate}' : '--',
                    'bpm'),
                _SensorValue(
                    'SpO2', metrics.hasSpo2 ? '${metrics.spo2}' : '--', '%'),
                _SensorValue(
                    'HRV',
                    metrics.hasHrv ? metrics.hrv!.toStringAsFixed(0) : '--',
                    'ms'),
                _SensorValue(
                    'GSR',
                    metrics.hasGsr
                        ? metrics.gsrLevel!.toStringAsFixed(0)
                        : '--',
                    'score'),
                _SensorValue(
                    'Temp',
                    metrics.hasBodyTemperature
                        ? metrics.temperatureC.toStringAsFixed(1)
                        : '--',
                    'C'),
                _SensorValue(
                    'ECG',
                    metrics.hasEcg ? metrics.ecgMv!.toStringAsFixed(2) : '--',
                    'mV'),
                _SensorValue(
                    'Accel',
                    _triple(
                        metrics.accelXG, metrics.accelYG, metrics.accelZG, 2),
                    'g'),
                _SensorValue(
                    'Gyro',
                    _triple(metrics.gyroXDps, metrics.gyroYDps,
                        metrics.gyroZDps, 0),
                    'dps'),
                _SensorValue(
                    'Pressure',
                    metrics.hasPressure
                        ? metrics.pressureHpa!.toStringAsFixed(1)
                        : '--',
                    'hPa'),
                _SensorValue(
                    'Altitude',
                    metrics.hasAltitude
                        ? metrics.altitudeM!.toStringAsFixed(0)
                        : '--',
                    'm'),
                _SensorValue('GPS', gps, ''),
                _SensorValue('Battery',
                    metrics.hasBattery ? '${metrics.batteryPct}' : '--', '%'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _triple(double? x, double? y, double? z, int decimals) {
    if (x == null || y == null || z == null) return '--';
    return '${x.toStringAsFixed(decimals)}, ${y.toStringAsFixed(decimals)}, ${z.toStringAsFixed(decimals)}';
  }
}

class _SensorGrid extends StatelessWidget {
  const _SensorGrid({required this.values});

  final List<_SensorValue> values;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 520 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: values.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: columns == 3 ? 2.35 : 1.55,
          ),
          itemBuilder: (context, index) => _SensorTile(value: values[index]),
        );
      },
    );
  }
}

class _SensorValue {
  const _SensorValue(this.label, this.value, this.unit);

  final String label;
  final String value;
  final String unit;
}

class _SensorTile extends StatelessWidget {
  const _SensorTile({required this.value});

  final _SensorValue value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBFA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value.label,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value.unit.isEmpty ? value.value : '${value.value} ${value.unit}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignalQualityCard extends StatelessWidget {
  const _SignalQualityCard({required this.quality});

  final SensorQuality quality;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Signal quality',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _QualityBar(label: 'PPG quality', value: quality.ppg),
            _QualityBar(label: 'ECG quality', value: quality.ecg),
            _QualityBar(label: 'GSR quality', value: quality.gsr),
            _QualityBar(
                label: 'Temperature contact', value: quality.temperature),
            _QualityBar(label: 'Motion quality', value: quality.motion),
            _QualityBar(label: 'GPS readiness', value: quality.gps),
            const SizedBox(height: 10),
            for (final note in quality.notes)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('• $note'),
              ),
          ],
        ),
      ),
    );
  }
}

class _QualityBar extends StatelessWidget {
  const _QualityBar({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final color = value >= 0.75
        ? tealColor
        : value >= 0.5
            ? amberColor
            : coralColor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text('${(value * 100).toStringAsFixed(0)}%'),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: value.clamp(0, 1).toDouble(),
              minHeight: 8,
              color: color,
              backgroundColor: color.withOpacity(0.12),
            ),
          ),
        ],
      ),
    );
  }
}

class _BaselineCard extends StatelessWidget {
  const _BaselineCard({required this.profile});

  final BaselineProfile profile;

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
                Expanded(
                  child: Text(
                    'Personal baseline',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(profile.activityContext),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: profile.completion,
              minHeight: 8,
              color: tealColor,
              backgroundColor: mintColor,
            ),
            const SizedBox(height: 12),
            for (final metric in profile.metrics)
              _BaselineMetricRow(metric: metric),
          ],
        ),
      ),
    );
  }
}

class _BaselineMetricRow extends StatelessWidget {
  const _BaselineMetricRow({required this.metric});

  final BaselineMetric metric;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  metric.label,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Text('${metric.sampleCount} samples'),
            ],
          ),
          const SizedBox(height: 5),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniPill('Now', _formatMetric(metric.current, metric.unit)),
              _MiniPill('Mean', _formatMetric(metric.mean, metric.unit)),
              _MiniPill('Std', _formatMetric(metric.stdDeviation, metric.unit)),
              _MiniPill('Dev', _formatMetric(metric.deviation, metric.unit)),
              _MiniPill(
                'Z',
                metric.zScore == null
                    ? '--'
                    : metric.zScore!.toStringAsFixed(1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AlgorithmCard extends StatelessWidget {
  const _AlgorithmCard({required this.output});

  final AlgorithmOutput output;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AI / algorithm output',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _QualityBar(label: 'Stress score', value: output.stressScore / 100),
            _QualityBar(
              label: 'ECG anomaly probability',
              value: output.ecgAnomalyProbability / 100,
            ),
            _QualityBar(
              label: 'Fall probability',
              value: output.fallProbability / 100,
            ),
            _MiniPill('Activity', output.activity),
          ],
        ),
      ),
    );
  }
}

class _NeuroTwinOutputCard extends StatelessWidget {
  const _NeuroTwinOutputCard({required this.snapshot});

  final NeuroTwinSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(snapshot.category);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('NeuroTwin output',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.12),
                  foregroundColor: color,
                  child: const Icon(Icons.auto_graph_rounded),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${snapshot.category.label} • ${snapshot.riskScore.toStringAsFixed(0)}/100',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Detected deviations',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            for (final item in snapshot.detectedDeviations)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('• $item'),
              ),
            const SizedBox(height: 12),
            const Text(
              'Reasons contributing to risk',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            for (final item in snapshot.riskReasons)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('• $item'),
              ),
          ],
        ),
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.trend});

  final TrendResult trend;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Trend analysis',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MiniPill('5 min', _percent(trend.fiveMinuteAverage)),
                _MiniPill('30 min', _percent(trend.thirtyMinuteAverage)),
                _MiniPill('1 hour', _percent(trend.oneHourAverage)),
                _MiniPill('Direction', trend.direction),
              ],
            ),
            const SizedBox(height: 10),
            Text(trend.message),
          ],
        ),
      ),
    );
  }
}

class _SafetyLanguageCard extends StatelessWidget {
  const _SafetyLanguageCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      color: Color(0xFFFFF4DC),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Safety note: NeuroTwin shows wellness risk patterns and sensor-quality warnings. It does not diagnose heart attack, cardiac arrest, or any disease.',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill(this.label, this.value);

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

Color _categoryColor(NeuroTwinRiskCategory category) {
  switch (category) {
    case NeuroTwinRiskCategory.normal:
      return tealColor;
    case NeuroTwinRiskCategory.observe:
      return amberColor;
    case NeuroTwinRiskCategory.warning:
      return const Color(0xFFE06B2E);
    case NeuroTwinRiskCategory.criticalReview:
      return coralColor;
  }
}

String _formatMetric(double? value, String unit) {
  if (value == null) return '--';
  final decimals = value.abs() >= 10 ? 0 : 1;
  return '${value.toStringAsFixed(decimals)} $unit';
}

String _percent(double? value) =>
    value == null ? '--' : value.toStringAsFixed(0);
