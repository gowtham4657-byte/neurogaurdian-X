import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/emergency_config.dart';
import '../../core/theme.dart';
import 'auto_sos_provider.dart';
import 'emergency_notification_service.dart';
import 'medical_facility.dart';
import 'medical_facility_service.dart';
import '../metrics/metrics.dart';
import '../metrics/metrics_providers.dart';
import '../settings/user_settings.dart';

class SosScreen extends ConsumerStatefulWidget {
  const SosScreen({super.key});

  @override
  ConsumerState<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends ConsumerState<SosScreen> {
  final _guardianController = TextEditingController(text: defaultGuardianPhone);
  final _ambulanceController =
      TextEditingController(text: defaultAmbulancePhone);
  final _pushTargetController = TextEditingController(
    text: EmergencyConfig.guardianPushTarget,
  );
  final _backendUrlController = TextEditingController(
    text: EmergencyConfig.backendUrl,
  );
  final _backendTokenController = TextEditingController(
    text: EmergencyConfig.backendToken,
  );
  final _facilityService = const MedicalFacilityService();
  final _notificationService = const EmergencyNotificationService();
  String? _status;
  bool _sending = false;
  bool _savingContacts = false;
  bool _settingsApplied = false;
  DateTime? _handledAutoTrigger;

  @override
  void dispose() {
    _guardianController.dispose();
    _ambulanceController.dispose();
    _pushTargetController.dispose();
    _backendUrlController.dispose();
    _backendTokenController.dispose();
    super.dispose();
  }

  Future<void> _sendSms(
    Metrics? metrics, {
    AutoSosTriggerReason reason = AutoSosTriggerReason.none,
  }) async {
    final automatic = reason != AutoSosTriggerReason.none;
    await _saveContacts(silent: true);
    final phone = _recipientFor(reason);
    if (!_isUsablePhone(phone)) {
      setState(
        () => _status = automatic
            ? 'Add a real hospital / ambulance contact before relying on auto SOS.'
            : 'Add a real guardian phone number before sending SOS.',
      );
      return;
    }

    setState(() {
      _sending = true;
      _status = switch (reason) {
        AutoSosTriggerReason.suddenHeartRateDrop =>
          'Critical fall detected. Opening ambulance SOS...',
        AutoSosTriggerReason.noMovement =>
          'Auto SOS triggered. Checking location permission...',
        AutoSosTriggerReason.none => 'Checking location permission...',
      };
    });

    try {
      await ref.read(bleRepositoryProvider).sendCommand('BUZZER_ON');
      final location = await _getBestSosLocation(metrics, 'Getting GPS fix...');
      if (location == null) return;

      final settings =
          ref.read(userSettingsProvider).valueOrNull ?? UserSettings.defaults();
      setState(() => _status = 'Finding nearest medical facilities...');
      final facilities = await _safeNearbyFacilities(location, settings);
      final message = _message(location, metrics, reason, facilities);
      final backendResult = await _notificationService.notifyBackend(
        settings: settings,
        reason: reason,
        alertMessage: message,
        latitude: location.latitude,
        longitude: location.longitude,
        accuracyM: location.accuracyM,
        mapsLink: _locationUrl(location),
        nearbyHospitalsLink: _nearbyHospitalsUrl(location),
        facilities: facilities,
        metrics: metrics,
      );

      if (!backendResult.sent) {
        final fallbackStatus = automatic
            ? await _openSmsFallback(phone, message)
            : await _openGuardianWhatsAppOrSms(settings.guardianPhone, message);
        setState(() => _status = '${backendResult.message} $fallbackStatus');
        return;
      }

      setState(() => _status = backendResult.message);
    } catch (e) {
      setState(() => _status = 'SOS failed: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _message(
    _SosLocation location,
    Metrics? metrics,
    AutoSosTriggerReason reason,
    List<MedicalFacility> facilities,
  ) {
    final vitals =
        metrics == null ? 'No live vitals available.' : _vitalsLine(metrics);
    final facilityText = facilities.isEmpty
        ? 'Nearest medical facilities: ${_nearbyHospitalsUrl(location)}.'
        : 'Top nearby medical facilities: ${_facilitiesLine(facilities)}';
    return 'SOS from NeuroGuardian X. ${reason.message} $vitals Patient GPS (${location.source}): ${_locationUrl(location)}. $facilityText Accuracy about ${location.accuracyText}.';
  }

  Future<List<MedicalFacility>> _safeNearbyFacilities(
    _SosLocation location,
    UserSettings settings,
  ) async {
    try {
      return await _facilityService.nearbyHospitals(
        latitude: location.latitude,
        longitude: location.longitude,
        backendUrl: settings.emergencyBackendUrl,
        backendToken: settings.emergencyBackendToken,
      );
    } catch (_) {
      return const [];
    }
  }

  Future<void> _openNearbyHospitals(Metrics? metrics) async {
    setState(() {
      _sending = true;
      _status = 'Finding nearby hospitals from GPS...';
    });

    try {
      final location = await _getBestSosLocation(
        metrics,
        'Getting GPS for hospital search...',
      );
      if (location == null) return;
      final uri = Uri.parse(_nearbyHospitalsUrl(location));
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      setState(
        () => _status = opened
            ? 'Nearby hospital map opened.'
            : 'Could not open nearby hospital map.',
      );
    } catch (e) {
      setState(() => _status = 'Nearby hospital search failed: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<_SosLocation?> _getBestSosLocation(
    Metrics? metrics,
    String loadingStatus,
  ) async {
    if (_hasWatchGps(metrics)) {
      final accuracy = metrics!.gpsAccuracyM;
      return _SosLocation(
        latitude: metrics.latitude!,
        longitude: metrics.longitude!,
        accuracyM: accuracy,
        source: 'watch GPS',
      );
    }

    return _getPhoneGpsPosition(loadingStatus);
  }

  Future<_SosLocation?> _getPhoneGpsPosition(String loadingStatus) async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      setState(() => _status = 'Turn on location services, then try again.');
      return null;
    }

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever ||
        perm == LocationPermission.denied) {
      setState(() => _status = 'Location permission denied.');
      return null;
    }

    setState(() => _status = loadingStatus);
    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 10),
    );
    return _SosLocation(
      latitude: pos.latitude,
      longitude: pos.longitude,
      accuracyM: pos.accuracy,
      source: 'phone GPS fallback',
    );
  }

  Future<void> _requestBackgroundLocation() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      setState(() => _status = 'Turn on location services first.');
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.whileInUse) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.always) {
      setState(() => _status = 'Background location is allowed.');
      return;
    }

    await Geolocator.openAppSettings();
    setState(
      () => _status =
          'In Android settings, choose Location > Allow all the time for stronger locked-phone SOS.',
    );
  }

  bool _hasWatchGps(Metrics? metrics) {
    final latitude = metrics?.latitude;
    final longitude = metrics?.longitude;
    if (latitude == null || longitude == null) return false;
    if (latitude == 0 && longitude == 0) return false;
    return latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  String _locationUrl(_SosLocation location) =>
      'https://maps.google.com/?q=${location.latitude},${location.longitude}';

  String _nearbyHospitalsUrl(_SosLocation location) =>
      'https://www.google.com/maps/search/nearby+hospitals/@${location.latitude},${location.longitude},14z';

  String _facilitiesLine(List<MedicalFacility> facilities) {
    return facilities.take(3).map((item) => item.compactLine).join(' | ');
  }

  Future<String> _openGuardianWhatsAppOrSms(
    String guardianPhone,
    String message,
  ) async {
    final whatsappOpened = await _openWhatsAppFallback(guardianPhone, message);
    if (whatsappOpened) return 'WhatsApp fallback opened.';
    return _openSmsFallback(guardianPhone, message);
  }

  Future<bool> _openWhatsAppFallback(String phone, String message) async {
    final number = _whatsappNumber(phone);
    if (number.isEmpty) return false;
    final uri = Uri.parse(
      'https://wa.me/$number?text=${Uri.encodeComponent(message)}',
    );
    try {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  Future<String> _openSmsFallback(String phone, String message) async {
    final msg = Uri.encodeComponent(message);
    final uri = Uri.parse('sms:$phone?body=$msg');
    final opened = await launchUrl(uri);
    return opened ? 'SMS fallback opened.' : 'Could not open SMS fallback.';
  }

  String _whatsappNumber(String phone) {
    return phone.replaceAll(RegExp(r'[^0-9]'), '');
  }

  String _recipientFor(AutoSosTriggerReason reason) {
    if (reason == AutoSosTriggerReason.none) {
      return _guardianController.text.trim();
    }
    return _ambulanceController.text.trim();
  }

  bool _isUsablePhone(String phone) {
    final value = phone.trim();
    return value.isNotEmpty && !value.contains('X');
  }

  Future<void> _saveContacts({bool silent = false}) async {
    final guardian = _guardianController.text.trim();
    final ambulance = _ambulanceController.text.trim();
    final pushTarget = _configuredOrFallback(
      _pushTargetController.text,
      EmergencyConfig.guardianPushTarget,
    );
    final backendUrl = _configuredOrFallback(
      _backendUrlController.text,
      EmergencyConfig.backendUrl,
    );
    final backendToken = _configuredOrFallback(
      _backendTokenController.text,
      EmergencyConfig.backendToken,
    );
    if (!silent) {
      setState(() {
        _savingContacts = true;
        _status = 'Saving emergency settings locally...';
      });
    }

    try {
      await ref.read(userSettingsProvider.notifier).updateContacts(
            guardianPhone: guardian,
            ambulancePhone: ambulance,
            guardianPushTarget: pushTarget,
            emergencyBackendUrl: backendUrl,
            emergencyBackendToken: backendToken,
          );
      if (!silent && mounted) {
        setState(() => _status = 'Emergency settings saved on this device.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _status = 'Could not save contacts: $e');
      }
    } finally {
      if (!silent && mounted) {
        setState(() => _savingContacts = false);
      }
    }
  }

  String _valueOrFallback(String value, String fallback) {
    final text = value.trim();
    return text.isEmpty ? fallback : text;
  }

  String _configuredOrFallback(String value, String configured) {
    final config = configured.trim();
    if (config.isNotEmpty) return config;
    return _valueOrFallback(value, config);
  }

  void _applySettings(UserSettings settings) {
    if (_settingsApplied) return;
    _settingsApplied = true;
    _guardianController.text = settings.guardianPhone;
    _ambulanceController.text = settings.ambulancePhone;
    _pushTargetController.text = _configuredOrFallback(
      settings.guardianPushTarget,
      EmergencyConfig.guardianPushTarget,
    );
    _backendUrlController.text = _configuredOrFallback(
      settings.emergencyBackendUrl,
      EmergencyConfig.backendUrl,
    );
    _backendTokenController.text = _configuredOrFallback(
      settings.emergencyBackendToken,
      EmergencyConfig.backendToken,
    );
  }

  void _cancelAutoSos() {
    ref.read(autoSosProvider.notifier).reset();
    unawaited(ref.read(bleRepositoryProvider).sendCommand('BUZZER_OFF'));
    setState(() => _status = 'Emergency timer canceled. Watch buzzer stopped.');
  }

  @override
  Widget build(BuildContext context) {
    final metrics = ref.watch(latestMetricsProvider);
    final autoSos = ref.watch(autoSosProvider);
    final settings = ref.watch(userSettingsProvider).valueOrNull;
    if (settings != null && !_settingsApplied) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applySettings(settings);
      });
    }

    ref.listen<AutoSosState>(autoSosProvider, (previous, next) {
      final triggeredAt = next.triggeredAt;
      if (triggeredAt == null || triggeredAt == _handledAutoTrigger) return;
      _handledAutoTrigger = triggeredAt;
      Future.microtask(
        () => _sendSms(
          ref.read(latestMetricsProvider),
          reason: next.triggerReason,
        ),
      );
    });

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Emergency', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          const Text(
            'Wearable owners add their own guardian WhatsApp number here. Automatic fall alerts use backend WhatsApp/push when configured, then SMS fallback.',
          ),
          const SizedBox(height: 18),
          const _SafetyNoticeCard(),
          const SizedBox(height: 12),
          if (autoSos.isVisible) ...[
            _AutoSosCard(
              state: autoSos,
              onCancel: _cancelAutoSos,
            ),
            const SizedBox(height: 12),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Guardian WhatsApp contact',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _guardianController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone_outlined),
                      labelText: 'Guardian WhatsApp number',
                      hintText: '+91XXXXXXXXXX',
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Added by the wearable owner. Manual SOS and automatic WhatsApp alerts use this number.',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hospital / ambulance contact',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _ambulanceController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.local_hospital_outlined),
                      labelText: 'Ambulance number',
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Used automatically after a serious fall pattern. SOS includes watch GPS if available, phone GPS fallback, and a nearby-hospital map link.',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
          if (EmergencyConfig.showAdvancedSosSettings) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Guardian push target',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _pushTargetController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.notifications_active_outlined),
                        labelText: 'Push token / guardian ID',
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Used by your emergency backend to send push notification redundancy.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WhatsApp + push backend',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _backendUrlController,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.cloud_done_outlined),
                        labelText: 'Backend URL',
                        hintText: 'https://your-server.com/api',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _backendTokenController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.key_outlined),
                        labelText: 'Backend device token',
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Do not store Google Maps or SuperSend secret keys in the app. Keep those on the backend.',
                      style: TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: mintColor,
                foregroundColor: tealColor,
                child: Icon(Icons.my_location_rounded),
              ),
              title: const Text(
                'Locked-phone GPS readiness',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: const Text(
                'Request background location so emergency alerts can include GPS when the phone is locked.',
              ),
              trailing: FilledButton(
                onPressed: _requestBackgroundLocation,
                child: const Text('Allow'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _savingContacts ? null : () => _saveContacts(),
            icon: _savingContacts
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Save emergency settings'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _sending ? null : () => _openNearbyHospitals(metrics),
            icon: const Icon(Icons.local_hospital_outlined),
            label: const Text('Open nearby hospitals'),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Message preview',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  Text(_preview(metrics)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(64),
              backgroundColor: coralColor,
            ),
            onPressed: _sending ? null : () => _sendSms(metrics),
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.sos_rounded),
            label: const Text('Send SOS'),
          ),
          const SizedBox(height: 12),
          if (_status != null)
            Text(
              _status!,
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  String _preview(Metrics? metrics) {
    final gpsSource =
        _hasWatchGps(metrics) ? 'watch GPS' : 'phone GPS fallback when sending';
    if (metrics == null) {
      return 'SOS from NeuroGuardian X with GPS, live location link, top 3 medical facilities when configured, and nearby-hospital fallback link. No live vitals available.';
    }
    return 'SOS from NeuroGuardian X with $gpsSource, Google Maps link, top 3 medical facilities when configured, automatic guardian alert when configured, and ${_vitalsLine(metrics)}';
  }

  String _vitalsLine(Metrics metrics) {
    final values = [
      if (metrics.hasHeartRate) 'HR ${metrics.heartRate} bpm',
      if (metrics.hasSpo2) 'SpO2 ${metrics.spo2}%',
      if (metrics.hasGsr || metrics.hasHeartRate)
        'stress ${metrics.stressLevel.toStringAsFixed(0)}',
      if (metrics.gsrLevel != null)
        'GSR ${metrics.gsrLevel!.toStringAsFixed(0)}',
      if (metrics.hasEcg) 'ECG ${metrics.ecgMv!.toStringAsFixed(2)} mV',
      if (metrics.hasBodyTemperature)
        'temp ${metrics.temperatureC.toStringAsFixed(1)} C',
      if (metrics.hasBattery) 'battery ${metrics.batteryPct}%',
      metrics.movementDetected ? 'movement detected' : 'no movement',
    ];
    if (values.length == 1) return 'Valid vitals are still loading.';
    return '${values.join(', ')}.';
  }
}

class _SosLocation {
  const _SosLocation({
    required this.latitude,
    required this.longitude,
    required this.source,
    this.accuracyM,
  });

  final double latitude;
  final double longitude;
  final double? accuracyM;
  final String source;

  String get accuracyText =>
      accuracyM == null ? 'unknown' : '${accuracyM!.toStringAsFixed(0)} m';
}

class _SafetyNoticeCard extends StatelessWidget {
  const _SafetyNoticeCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFFFF4DC),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, color: amberColor),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Safety note: most phones open the SMS composer for user confirmation if automatic alert service is not available. True nearest-hospital dispatch needs verified emergency integration, testing, and local legal review.',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AutoSosCard extends StatelessWidget {
  const _AutoSosCard({required this.state, required this.onCancel});

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
      child: ListTile(
        leading: Icon(
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
        title: Text(
          triggered
              ? state.triggerReason.title
              : canceled
                  ? 'Movement detected'
                  : 'Ambulance SOS in ${state.secondsRemaining}s',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          triggered
              ? state.triggerReason == AutoSosTriggerReason.suddenHeartRateDrop
                  ? 'Ambulance SOS opens immediately for fall plus sudden heart-rate drop.'
                  : 'Possible unconscious fall: no movement crossed 30 seconds, so ambulance SOS opens.'
              : canceled
                  ? 'The watch detected movement, so the timer stopped.'
                  : 'Movement after the fall stops the timer. No movement opens ambulance SOS.',
        ),
        trailing: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: canceled ? tealColor : inkColor,
            foregroundColor: Colors.white,
          ),
          onPressed: onCancel,
          icon: const Icon(Icons.check_circle_rounded),
          label: const Text('I AM OKAY'),
        ),
      ),
    );
  }
}
