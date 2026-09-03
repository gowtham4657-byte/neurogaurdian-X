import 'package:flutter/services.dart';

class DeviceEmergencyConfig {
  const DeviceEmergencyConfig({
    this.backendUrl = '',
    this.backendToken = '',
    this.guardianPushTarget = '',
  });

  static const _channel = MethodChannel('com.neuroguardian.config');

  final String backendUrl;
  final String backendToken;
  final String guardianPushTarget;

  static Future<DeviceEmergencyConfig> load() async {
    try {
      final raw = await _channel.invokeMethod<Map>('getEmergencyConfig');
      return DeviceEmergencyConfig(
        backendUrl: _stringValue(raw?['backendUrl']),
        backendToken: _stringValue(raw?['backendToken']),
        guardianPushTarget: _stringValue(raw?['guardianPushTarget']),
      );
    } catch (_) {
      return const DeviceEmergencyConfig();
    }
  }

  static String _stringValue(Object? value) => value?.toString().trim() ?? '';
}
