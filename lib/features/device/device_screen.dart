import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../ble/ble_repository.dart';
import '../metrics/metrics_providers.dart';

class DeviceScreen extends ConsumerWidget {
  const DeviceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(wearableConnectionProvider).valueOrNull ??
        'Wearable not connected';
    final devices = ref.watch(discoveredWearablesProvider).valueOrNull ?? [];
    final repo = ref.read(bleRepositoryProvider);

    Future<void> runBleAction(Future<void> Function() action) async {
      try {
        await action();
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Wearable action failed: $e')),
        );
      }
    }

    return SafeArea(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF6FBF8), Color(0xFFFFF7EE)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Wearable', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            const Text(
              'Connect the NeuroGuardian watch and stream live safety data.',
            ),
            const SizedBox(height: 16),
            _ConnectionCard(
              status: status,
              onScan: () => runBleAction(repo.startScan),
              onStopScan: () => runBleAction(repo.stopScan),
              onDisconnect: () => runBleAction(repo.disconnect),
            ),
            const SizedBox(height: 12),
            _DeviceList(
              devices: devices,
              onConnect: (id) => runBleAction(() => repo.connectTo(id)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({
    required this.status,
    required this.onScan,
    required this.onStopScan,
    required this.onDisconnect,
  });

  final String status;
  final Future<void> Function() onScan;
  final Future<void> Function() onStopScan;
  final Future<void> Function() onDisconnect;

  @override
  Widget build(BuildContext context) {
    final connected = status.toLowerCase().contains('connected') &&
        !status.toLowerCase().contains('disconnected');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      (connected ? tealColor : amberColor).withOpacity(0.14),
                  foregroundColor: connected ? tealColor : amberColor,
                  child: Icon(
                    connected
                        ? Icons.bluetooth_connected_rounded
                        : Icons.bluetooth_searching_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Wearable connection',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(status),
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
                FilledButton.icon(
                  onPressed: onScan,
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('Scan for wearable'),
                ),
                OutlinedButton.icon(
                  onPressed: onStopScan,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('Stop scan'),
                ),
                OutlinedButton.icon(
                  onPressed: onDisconnect,
                  icon: const Icon(Icons.link_off_rounded),
                  label: const Text('Disconnect'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceList extends StatelessWidget {
  const _DeviceList({required this.devices, required this.onConnect});

  final List<WearableDevice> devices;
  final Future<void> Function(String id) onConnect;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Discovered devices',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (devices.isEmpty)
              const Text(
                'Tap scan. Keep Bluetooth and Location turned on. Your watch should appear as "NeuroGuardianX".',
              )
            else
              for (final device in devices)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: device.likelyNeuroGuardian
                        ? mintColor
                        : const Color(0xFFF2F4F7),
                    foregroundColor:
                        device.likelyNeuroGuardian ? tealColor : Colors.black54,
                    child: Icon(
                      device.likelyNeuroGuardian
                          ? Icons.watch_rounded
                          : Icons.bluetooth_rounded,
                    ),
                  ),
                  title: Text(
                    device.name,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    '${device.id}\nRSSI ${device.rssi} dBm - '
                    '${device.connectable ? 'connectable' : 'connect anyway'}',
                  ),
                  isThreeLine: true,
                  trailing: FilledButton(
                    onPressed: () => onConnect(device.id),
                    child: const Text('Connect'),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
