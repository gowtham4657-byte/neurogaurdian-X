import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../emergency/auto_sos_provider.dart';
import '../metrics/metrics_providers.dart';
import '../sleep/sleep_repository.dart';
import 'care_plan.dart';
import 'prescription_repository.dart';

class CareScreen extends ConsumerStatefulWidget {
  const CareScreen({super.key});

  @override
  ConsumerState<CareScreen> createState() => _CareScreenState();
}

class _CareScreenState extends ConsumerState<CareScreen> {
  final _medicineController = TextEditingController();
  final _doseController = TextEditingController();
  final _timingController = TextEditingController();
  final _doctorController = TextEditingController();
  bool _addingPrescription = false;
  bool _savingSleep = false;
  double _sleepHours = 7.5;
  int _sleepQuality = 75;

  @override
  void dispose() {
    _medicineController.dispose();
    _doseController.dispose();
    _timingController.dispose();
    _doctorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final metrics = ref.watch(latestMetricsProvider);
    final risk = ref.watch(riskScoresProvider);
    final autoSos = ref.watch(autoSosProvider);
    final prescriptions = ref.watch(prescriptionsProvider);
    final sleepLogs = ref.watch(sleepLogsProvider);
    final sleepInsights = ref.watch(sleepInsightsProvider);
    final plan = buildCarePlan(metrics, risk, autoSos);

    return SafeArea(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFFBF2), Color(0xFFEAF7F3)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Care Guide',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            const Text('Suggestions adapt to the latest detected criteria.'),
            const SizedBox(height: 16),
            _CareStatusCard(plan: plan),
            const SizedBox(height: 12),
            if (plan.isSerious)
              const _ConsultDoctorCard()
            else ...[
              _SuggestionSection(title: 'Home remedies', items: plan.homeCare),
              const SizedBox(height: 12),
              _SuggestionSection(
                  title: 'Exercise suggestions', items: plan.exercises),
            ],
            const SizedBox(height: 12),
            _SleepTrackerSection(
              logs: sleepLogs,
              insights: sleepInsights,
              hours: _sleepHours,
              quality: _sleepQuality,
              saving: _savingSleep,
              onHoursChanged: (value) => setState(() {
                _sleepHours = (value * 2).round() / 2;
              }),
              onQualityChanged: (value) => setState(() {
                _sleepQuality = value.round();
              }),
              onSave: _saveSleepLog,
              onRemove: (log) =>
                  ref.read(sleepLogsProvider.notifier).remove(log.id),
            ),
            const SizedBox(height: 12),
            _PrescriptionSection(
              prescriptions: prescriptions,
              adding: _addingPrescription,
              medicineController: _medicineController,
              doseController: _doseController,
              timingController: _timingController,
              doctorController: _doctorController,
              onAdd: _addPrescription,
              onRemove: (item) =>
                  ref.read(prescriptionsProvider.notifier).remove(item.id),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addPrescription() async {
    final medicine = _medicineController.text.trim();
    final dose = _doseController.text.trim();
    final timing = _timingController.text.trim();
    final doctor = _doctorController.text.trim();
    if (medicine.isEmpty || dose.isEmpty || timing.isEmpty) return;

    setState(() => _addingPrescription = true);
    await ref.read(prescriptionsProvider.notifier).add(
          medicine: medicine,
          dose: dose,
          timing: timing,
          doctor: doctor,
        );
    if (!mounted) return;
    setState(() {
      _medicineController.clear();
      _doseController.clear();
      _timingController.clear();
      _doctorController.clear();
      _addingPrescription = false;
    });
  }

  Future<void> _saveSleepLog() async {
    setState(() => _savingSleep = true);
    await ref.read(sleepLogsProvider.notifier).add(
          date: DateTime.now(),
          hours: _sleepHours,
          quality: _sleepQuality,
        );
    if (!mounted) return;
    setState(() => _savingSleep = false);
  }
}

class _CareStatusCard extends StatelessWidget {
  const _CareStatusCard({required this.plan});

  final CarePlan plan;

  @override
  Widget build(BuildContext context) {
    final color = plan.isSerious ? coralColor : tealColor;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                plan.isSerious
                    ? Icons.local_hospital_rounded
                    : Icons.spa_rounded,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plan.title,
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(plan.summary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConsultDoctorCard extends StatelessWidget {
  const _ConsultDoctorCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFFFE7E7),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Row(
              children: [
                Icon(Icons.medical_services_rounded, color: coralColor),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Consult doctor',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'The detected criteria are serious. Do not start exercise or home remedies as the main response. Contact a doctor, guardian, hospital, or ambulance.',
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionSection extends StatelessWidget {
  const _SuggestionSection({required this.title, required this.items});

  final String title;
  final List<CareSuggestion> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final item in items) _SuggestionCard(item: item),
      ],
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.item});

  final CareSuggestion item;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: mintColor,
          foregroundColor: tealColor,
          child: Icon(_iconFor(item.icon)),
        ),
        title: Text(item.title,
            style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(item.detail),
      ),
    );
  }

  IconData _iconFor(CareIcon icon) {
    switch (icon) {
      case CareIcon.breathing:
        return Icons.self_improvement_rounded;
      case CareIcon.hydration:
        return Icons.water_drop_rounded;
      case CareIcon.cooling:
        return Icons.ac_unit_rounded;
      case CareIcon.rest:
        return Icons.bedtime_rounded;
      case CareIcon.walk:
        return Icons.directions_walk_rounded;
      case CareIcon.doctor:
        return Icons.local_hospital_rounded;
      case CareIcon.fall:
        return Icons.personal_injury_rounded;
    }
  }
}

class _SleepTrackerSection extends StatelessWidget {
  const _SleepTrackerSection({
    required this.logs,
    required this.insights,
    required this.hours,
    required this.quality,
    required this.saving,
    required this.onHoursChanged,
    required this.onQualityChanged,
    required this.onSave,
    required this.onRemove,
  });

  final AsyncValue<List<SleepLog>> logs;
  final SleepInsights insights;
  final double hours;
  final int quality;
  final bool saving;
  final ValueChanged<double> onHoursChanged;
  final ValueChanged<double> onQualityChanged;
  final VoidCallback onSave;
  final void Function(SleepLog log) onRemove;

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
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: mintColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.bedtime_rounded, color: tealColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sleep and recovery',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Text(
                        'Track sleep to explain stress and recovery trends.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _SleepScoreRing(score: insights.score),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SleepInfoRow(
                        label: 'Avg duration',
                        value: insights.nights == 0
                            ? '--'
                            : '${insights.avgHours.toStringAsFixed(1)}h',
                      ),
                      _SleepInfoRow(
                        label: 'Avg quality',
                        value: insights.nights == 0
                            ? '--'
                            : '${insights.avgQuality}/100',
                      ),
                      _SleepInfoRow(
                        label: 'Consistency',
                        value: insights.consistency,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DecoratedBox(
              decoration: BoxDecoration(
                color: creamColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  insights.tip,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _SleepSlider(
              label: 'Hours slept',
              value: hours,
              display: '${hours.toStringAsFixed(1)}h',
              min: 0,
              max: 14,
              divisions: 28,
              onChanged: onHoursChanged,
            ),
            _SleepSlider(
              label: 'Sleep quality',
              value: quality.toDouble(),
              display: '$quality/100',
              min: 0,
              max: 100,
              divisions: 20,
              onChanged: onQualityChanged,
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: saving ? null : onSave,
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded),
              label: const Text('Save sleep log'),
            ),
            const SizedBox(height: 12),
            logs.when(
              data: (items) => items.isEmpty
                  ? const Text('No sleep logs yet.')
                  : Column(
                      children: [
                        for (final log in items.take(4))
                          _SleepLogTile(
                            log: log,
                            onRemove: () => onRemove(log),
                          ),
                      ],
                    ),
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text(
                'Could not load sleep logs: $error',
                style: const TextStyle(color: coralColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SleepScoreRing extends StatelessWidget {
  const _SleepScoreRing({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final color = score >= 75
        ? tealColor
        : score >= 50
            ? amberColor
            : coralColor;
    return SizedBox(
      width: 92,
      height: 92,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: score / 100,
            strokeWidth: 8,
            backgroundColor: color.withOpacity(0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  score == 0 ? '--' : '$score',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Text(
                  'sleep',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SleepInfoRow extends StatelessWidget {
  const _SleepInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _SleepSlider extends StatelessWidget {
  const _SleepSlider({
    required this.label,
    required this.value,
    required this.display,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final double value;
  final String display;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
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
            Text(display, style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          activeColor: tealColor,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _SleepLogTile extends StatelessWidget {
  const _SleepLogTile({required this.log, required this.onRemove});

  final SleepLog log;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(
        backgroundColor: mintColor,
        foregroundColor: tealColor,
        child: Icon(Icons.nightlight_round),
      ),
      title: Text(
        '${log.hours.toStringAsFixed(1)}h sleep - ${log.quality}/100 quality',
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: Text(_formatDate(log.date)),
      trailing: IconButton(
        tooltip: 'Remove sleep log',
        onPressed: onRemove,
        icon: const Icon(Icons.delete_outline_rounded),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _PrescriptionSection extends StatelessWidget {
  const _PrescriptionSection({
    required this.prescriptions,
    required this.adding,
    required this.medicineController,
    required this.doseController,
    required this.timingController,
    required this.doctorController,
    required this.onAdd,
    required this.onRemove,
  });

  final AsyncValue<List<DoctorPrescription>> prescriptions;
  final bool adding;
  final TextEditingController medicineController;
  final TextEditingController doseController;
  final TextEditingController timingController;
  final TextEditingController doctorController;
  final VoidCallback onAdd;
  final void Function(DoctorPrescription item) onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Doctor prescription',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            const Text('Add medicines only when a doctor has prescribed them.'),
            const SizedBox(height: 12),
            TextField(
              controller: medicineController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.medication_rounded),
                labelText: 'Medicine name',
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: doseController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Dose',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: timingController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Timing',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: doctorController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_rounded),
                labelText: 'Doctor name',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: adding ? null : onAdd,
              icon: adding
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_rounded),
              label: const Text('Add doctor prescription'),
            ),
            const SizedBox(height: 12),
            prescriptions.when(
              data: (items) => items.isEmpty
                  ? const Text('No doctor-prescribed medicines added yet.')
                  : Column(
                      children: [
                        for (final item in items)
                          _PrescriptionTile(
                            item: item,
                            onRemove: () => onRemove(item),
                          ),
                      ],
                    ),
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text(
                'Could not load prescriptions: $error',
                style: const TextStyle(color: coralColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrescriptionTile extends StatelessWidget {
  const _PrescriptionTile({required this.item, required this.onRemove});

  final DoctorPrescription item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(
        backgroundColor: mintColor,
        foregroundColor: tealColor,
        child: Icon(Icons.medication_liquid_rounded),
      ),
      title: Text(item.medicine,
          style: const TextStyle(fontWeight: FontWeight.w900)),
      subtitle:
          Text('${item.dose} - ${item.timing}\nPrescribed by ${item.doctor}'),
      isThreeLine: true,
      trailing: IconButton(
        tooltip: 'Remove prescription',
        onPressed: onRemove,
        icon: const Icon(Icons.delete_outline_rounded),
      ),
    );
  }
}
