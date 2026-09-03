import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/device_emergency_config.dart';
import '../../core/emergency_config.dart';

const defaultGuardianPhone = '+91XXXXXXXXXX';
const defaultAmbulancePhone = '108';

final userSettingsProvider =
    StateNotifierProvider<UserSettingsController, AsyncValue<UserSettings>>(
  (ref) => UserSettingsController(),
);

class UserSettings {
  const UserSettings({
    required this.guardianPhone,
    required this.ambulancePhone,
    required this.guardianPushTarget,
    required this.emergencyBackendUrl,
    required this.emergencyBackendToken,
    required this.safetyAccepted,
    required this.acceptedAt,
  });

  factory UserSettings.defaults() {
    return const UserSettings(
      guardianPhone: defaultGuardianPhone,
      ambulancePhone: defaultAmbulancePhone,
      guardianPushTarget: EmergencyConfig.guardianPushTarget,
      emergencyBackendUrl: EmergencyConfig.backendUrl,
      emergencyBackendToken: EmergencyConfig.backendToken,
      safetyAccepted: false,
      acceptedAt: null,
    );
  }

  factory UserSettings.fromMap(Map raw) {
    final acceptedMs = raw['acceptedAt'] as int?;
    return UserSettings(
      guardianPhone:
          _valueOrDefault(raw['guardianPhone'], defaultGuardianPhone),
      ambulancePhone:
          _valueOrDefault(raw['ambulancePhone'], defaultAmbulancePhone),
      guardianPushTarget: _valueOrDefault(
        raw['guardianPushTarget'],
        EmergencyConfig.guardianPushTarget,
      ),
      emergencyBackendUrl: _configuredOrDefault(
        raw['emergencyBackendUrl'],
        EmergencyConfig.backendUrl,
      ),
      emergencyBackendToken: _configuredOrDefault(
        raw['emergencyBackendToken'],
        EmergencyConfig.backendToken,
      ),
      safetyAccepted: raw['safetyAccepted'] as bool? ?? false,
      acceptedAt: acceptedMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(acceptedMs),
    );
  }

  static String _valueOrDefault(Object? value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static String _configuredOrDefault(Object? value, String configured) {
    if (configured.trim().isNotEmpty) return configured.trim();
    return _valueOrDefault(value, configured);
  }

  final String guardianPhone;
  final String ambulancePhone;
  final String guardianPushTarget;
  final String emergencyBackendUrl;
  final String emergencyBackendToken;
  final bool safetyAccepted;
  final DateTime? acceptedAt;

  UserSettings withDeviceEmergencyConfig(DeviceEmergencyConfig config) {
    return copyWith(
      guardianPushTarget: _configuredOrDefault(
        guardianPushTarget,
        config.guardianPushTarget,
      ),
      emergencyBackendUrl: _configuredOrDefault(
        emergencyBackendUrl,
        config.backendUrl,
      ),
      emergencyBackendToken: _configuredOrDefault(
        emergencyBackendToken,
        config.backendToken,
      ),
    );
  }

  UserSettings copyWith({
    String? guardianPhone,
    String? ambulancePhone,
    String? guardianPushTarget,
    String? emergencyBackendUrl,
    String? emergencyBackendToken,
    bool? safetyAccepted,
    DateTime? acceptedAt,
  }) {
    return UserSettings(
      guardianPhone: guardianPhone ?? this.guardianPhone,
      ambulancePhone: ambulancePhone ?? this.ambulancePhone,
      guardianPushTarget: guardianPushTarget ?? this.guardianPushTarget,
      emergencyBackendUrl: emergencyBackendUrl ?? this.emergencyBackendUrl,
      emergencyBackendToken:
          emergencyBackendToken ?? this.emergencyBackendToken,
      safetyAccepted: safetyAccepted ?? this.safetyAccepted,
      acceptedAt: acceptedAt ?? this.acceptedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'guardianPhone': guardianPhone,
      'ambulancePhone': ambulancePhone,
      'guardianPushTarget': guardianPushTarget,
      'emergencyBackendUrl': emergencyBackendUrl,
      'emergencyBackendToken': emergencyBackendToken,
      'safetyAccepted': safetyAccepted,
      'acceptedAt': acceptedAt?.millisecondsSinceEpoch,
    };
  }
}

class UserSettingsController extends StateNotifier<AsyncValue<UserSettings>> {
  UserSettingsController() : super(const AsyncValue.loading()) {
    reload();
  }

  static const _boxName = 'user_settings';
  static const _settingsKey = 'settings';

  Box<Map>? _box;

  Future<void> reload() async {
    state = const AsyncValue.loading();
    try {
      final box = await _openBox();
      final raw = box.get(_settingsKey);
      final deviceConfig = await DeviceEmergencyConfig.load();
      state = AsyncValue.data(
        (raw == null ? UserSettings.defaults() : UserSettings.fromMap(raw))
            .withDeviceEmergencyConfig(deviceConfig),
      );
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> acceptSafetyChecklist() async {
    final current = await _current();
    await _save(
      current.copyWith(
        safetyAccepted: true,
        acceptedAt: DateTime.now(),
      ),
    );
  }

  Future<void> updateContacts({
    required String guardianPhone,
    required String ambulancePhone,
    String? guardianPushTarget,
    String? emergencyBackendUrl,
    String? emergencyBackendToken,
  }) async {
    final current = await _current();
    final deviceConfig = await DeviceEmergencyConfig.load();
    await _save(
      current
          .copyWith(
            guardianPhone: guardianPhone.trim(),
            ambulancePhone: ambulancePhone.trim(),
            guardianPushTarget: guardianPushTarget?.trim(),
            emergencyBackendUrl: emergencyBackendUrl?.trim(),
            emergencyBackendToken: emergencyBackendToken?.trim(),
          )
          .withDeviceEmergencyConfig(deviceConfig),
    );
  }

  Future<UserSettings> _current() async {
    final loaded = state.valueOrNull;
    if (loaded != null) return loaded;

    final box = await _openBox();
    final raw = box.get(_settingsKey);
    final deviceConfig = await DeviceEmergencyConfig.load();
    return (raw == null ? UserSettings.defaults() : UserSettings.fromMap(raw))
        .withDeviceEmergencyConfig(deviceConfig);
  }

  Future<void> _save(UserSettings settings) async {
    final box = await _openBox();
    await box.put(_settingsKey, settings.toMap());
    state = AsyncValue.data(settings);
  }

  Future<Box<Map>> _openBox() async {
    return _box ??= await Hive.openBox<Map>(_boxName);
  }
}
