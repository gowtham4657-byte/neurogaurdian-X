import 'package:flutter/material.dart';

import '../../core/theme.dart';

class SafetyConsentScreen extends StatelessWidget {
  const SafetyConsentScreen({
    super.key,
    required this.onAccept,
    required this.loading,
  });

  final VoidCallback onAccept;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFFBF2), Color(0xFFE1F2EC), Color(0xFFFFE2BC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _HeroMark(),
                        const SizedBox(height: 18),
                        Text(
                          'Before protection starts',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(color: inkColor, fontSize: 30),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'NeuroGuardian X helps watch for patterns and route SOS faster. It is not a diagnosis, not a substitute for a doctor, and must be tested with real contacts before community use.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: inkColor,
                            decoration: TextDecoration.none,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const _ChecklistCard(),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(58),
                            backgroundColor: inkColor,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: loading ? null : onAccept,
                          icon: loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.verified_user_rounded),
                          label: const Text('I understand, start protection'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HeroMark extends StatelessWidget {
  const _HeroMark();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 116,
        height: 116,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.14),
          border: Border.all(color: Colors.white.withOpacity(0.35)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66007C7A),
              blurRadius: 36,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: const Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.shield_rounded, color: Colors.white, size: 76),
            Positioned(
              bottom: 34,
              child: Icon(Icons.favorite_rounded, color: coralColor, size: 28),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChecklistCard extends StatelessWidget {
  const _ChecklistCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white.withOpacity(0.94),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            _SafetyPoint(
              icon: Icons.medical_information_outlined,
              title: 'Support, not diagnosis',
              body:
                  'The app detects risk patterns. Serious symptoms still need a clinician or emergency service.',
            ),
            _SafetyPoint(
              icon: Icons.sms_failed_outlined,
              title: 'SOS needs testing',
              body:
                  'Phone SMS apps may ask for confirmation. Test guardian and ambulance contacts before relying on it.',
            ),
            _SafetyPoint(
              icon: Icons.watch_outlined,
              title: 'Wearable quality matters',
              body:
                  'Loose sensors, low battery, Bluetooth dropouts, and bad calibration can cause missed or false alerts.',
            ),
            _SafetyPoint(
              icon: Icons.lock_outline_rounded,
              title: 'Local-first data',
              body:
                  'History, contacts, and prescriptions are stored on this device unless you add cloud sync later.',
            ),
          ],
        ),
      ),
    );
  }
}

class _SafetyPoint extends StatelessWidget {
  const _SafetyPoint({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    decoration: TextDecoration.none,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: const TextStyle(
                    decoration: TextDecoration.none,
                    fontSize: 13,
                    height: 1.28,
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
