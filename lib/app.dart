import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import 'core/theme.dart';
import 'features/alerts/alerts_providers.dart';
import 'features/analytics/analytics_screen.dart';
import 'features/care/care_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/device/device_screen.dart';
import 'features/emergency/auto_sos_provider.dart';
import 'features/emergency/sos_screen.dart';
import 'features/history/history_providers.dart';
import 'features/history/history_screen.dart';
import 'features/metrics/metrics_providers.dart';
import 'features/safety/safety_consent_screen.dart';
import 'features/settings/user_settings.dart';

class NeuroGuardianApp extends ConsumerWidget {
  const NeuroGuardianApp({super.key, this.skipSafetyGate = false});

  final bool skipSafetyGate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'NeuroGuardian X',
      theme: buildTheme(),
      home: skipSafetyGate ? const _Shell() : const _SafetyGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class _SafetyGate extends ConsumerWidget {
  const _SafetyGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(userSettingsProvider);

    return settings.when(
      data: (value) => value.safetyAccepted
          ? const _Shell()
          : SafetyConsentScreen(
              loading: false,
              onAccept: () => ref
                  .read(userSettingsProvider.notifier)
                  .acceptSafetyChecklist(),
            ),
      loading: () => const _LaunchScreen(),
      error: (error, _) => _SettingsError(
        error: error,
        onRetry: () => ref.read(userSettingsProvider.notifier).reload(),
      ),
    );
  }
}

class _LaunchScreen extends StatelessWidget {
  const _LaunchScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF061D1C), Color(0xFF0B706E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      ),
    );
  }
}

class _SettingsError extends StatelessWidget {
  const _SettingsError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 48),
              const SizedBox(height: 12),
              Text(
                'Could not load safety settings',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text('$error', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Shell extends ConsumerStatefulWidget {
  const _Shell();

  @override
  ConsumerState<_Shell> createState() => _ShellState();
}

class _ShellState extends ConsumerState<_Shell> {
  int _index = 0;

  final _screens = const [
    DashboardScreen(),
    AnalyticsScreen(),
    HistoryScreen(),
    CareScreen(),
    DeviceScreen(),
    SosScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    ref.read(historyRecorderProvider);
    ref.read(safetyAlertRecorderProvider);
    ref.listen<AutoSosState>(autoSosProvider, (previous, next) {
      final remainingChanged =
          previous?.secondsRemaining != next.secondsRemaining;
      final countdownStopped =
          previous?.isCountingDown == true && !next.isCountingDown;
      if (next.isCountingDown &&
          remainingChanged &&
          next.secondsRemaining > 0 &&
          next.secondsRemaining % 2 == 0) {
        HapticFeedback.heavyImpact();
        unawaited(ref.read(bleRepositoryProvider).sendCommand('BUZZER_ON'));
      }
      if (countdownStopped &&
          (next.isCanceled || next.status == AutoSosStatus.idle)) {
        unawaited(ref.read(bleRepositoryProvider).sendCommand('BUZZER_OFF'));
      }
      if (next.isTriggered && next.triggeredAt != previous?.triggeredAt) {
        HapticFeedback.vibrate();
        unawaited(ref.read(bleRepositoryProvider).sendCommand('BUZZER_ON'));
      }
      if (next.isTriggered && _index != 5) {
        setState(() => _index = 5);
      }
    });

    return Scaffold(
      body: _screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.monitor_heart_outlined),
            label: 'Live',
          ),
          NavigationDestination(
            icon: Icon(Icons.query_stats_outlined),
            label: 'Analytics',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            label: 'History',
          ),
          NavigationDestination(icon: Icon(Icons.spa_outlined), label: 'Care'),
          NavigationDestination(
            icon: Icon(Icons.watch_outlined),
            label: 'Device',
          ),
          NavigationDestination(icon: Icon(Icons.sos_outlined), label: 'SOS'),
        ],
      ),
    );
  }
}
