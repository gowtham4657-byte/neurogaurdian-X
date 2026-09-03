import 'dart:convert';

import 'package:http/http.dart' as http;

import '../metrics/metrics.dart';
import '../settings/user_settings.dart';
import 'auto_sos_provider.dart';
import 'medical_facility.dart';

class EmergencyNotificationResult {
  const EmergencyNotificationResult({
    required this.sent,
    required this.message,
  });

  final bool sent;
  final String message;
}

class EmergencyNotificationService {
  const EmergencyNotificationService();

  Future<EmergencyNotificationResult> notifyBackend({
    required UserSettings settings,
    required AutoSosTriggerReason reason,
    required String alertMessage,
    required double latitude,
    required double longitude,
    required double? accuracyM,
    required String mapsLink,
    required String nearbyHospitalsLink,
    required List<MedicalFacility> facilities,
    required Metrics? metrics,
  }) async {
    final backendUrl = settings.emergencyBackendUrl.trim();
    if (backendUrl.isEmpty) {
      return const EmergencyNotificationResult(
        sent: false,
        message: 'Emergency backend is not configured.',
      );
    }

    final uri = _endpointFor(backendUrl);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (settings.emergencyBackendToken.trim().isNotEmpty)
        'Authorization': 'Bearer ${settings.emergencyBackendToken.trim()}',
    };
    final body = {
      'event_type':
          reason == AutoSosTriggerReason.none ? 'manual_sos' : 'auto_sos',
      'reason': reason.name,
      'message': alertMessage,
      'summary': reason.message,
      'channels': ['whatsapp', 'push'],
      'guardian': {
        'phone': settings.guardianPhone,
        'push_target': settings.guardianPushTarget,
      },
      'ambulance_phone': settings.ambulancePhone,
      'location': {
        'latitude': latitude,
        'longitude': longitude,
        'accuracy_m': accuracyM,
        'maps_link': mapsLink,
        'nearby_hospitals_link': nearbyHospitalsLink,
      },
      'medical_facilities': facilities.map((item) => item.toMap()).toList(),
      'vitals': _metricsSnapshot(metrics),
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      final response = await http
          .post(uri, headers: headers, body: json.encode(body))
          .timeout(const Duration(seconds: 12));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = _safeJson(response.body);
        final sent = _backendAccepted(decoded);
        return EmergencyNotificationResult(
          sent: sent,
          message: sent
              ? 'Guardian WhatsApp/push backend accepted the alert.'
              : _backendStatusMessage(decoded),
        );
      }
      return EmergencyNotificationResult(
        sent: false,
        message: 'Backend failed with HTTP ${response.statusCode}.',
      );
    } catch (error) {
      return EmergencyNotificationResult(
        sent: false,
        message: 'Backend alert failed: $error',
      );
    }
  }

  Object? _safeJson(String body) {
    try {
      return json.decode(body);
    } catch (_) {
      return null;
    }
  }

  bool _backendAccepted(Object? decoded) {
    if (decoded is! Map) return true;
    if (decoded['whatsapp_sent'] == true) return true;
    final delivery = decoded['delivery'];
    if (delivery is Map && delivery['whatsapp'] == true) return true;
    final notifications = decoded['notifications'];
    if (notifications is List) {
      return notifications.whereType<Map>().any((item) {
        final channel = item['channel']?.toString().toLowerCase() ?? '';
        final isWhatsApp = channel == 'whatsapp' ||
            channel == 'whatsapp_cloud' ||
            channel == 'twilio_whatsapp';
        return isWhatsApp && item['sent'] == true;
      });
    }
    return false;
  }

  String _backendStatusMessage(Object? decoded) {
    if (decoded is Map) {
      final message = decoded['message'];
      if (message is String && message.isNotEmpty) return message;
      final notifications = decoded['notifications'];
      if (notifications is List && notifications.isNotEmpty) {
        return 'Backend reached but notification channels are not fully configured.';
      }
    }
    return 'Backend reached but did not confirm WhatsApp/push delivery.';
  }

  Uri _endpointFor(String backendUrl) {
    final normalized = backendUrl.endsWith('/')
        ? backendUrl.substring(0, backendUrl.length - 1)
        : backendUrl;
    final uri = Uri.parse(normalized);
    if (uri.path.endsWith('/emergency/alert')) return uri;
    return Uri.parse('$normalized/emergency/alert');
  }

  Map<String, Object?> _metricsSnapshot(Metrics? metrics) {
    if (metrics == null) return const {};
    return {
      'heart_rate': metrics.hasHeartRate ? metrics.heartRate : null,
      'spo2': metrics.hasSpo2 ? metrics.spo2 : null,
      'hrv': metrics.hasHrv ? metrics.hrv : null,
      'gsr': metrics.hasGsr ? metrics.gsrLevel : null,
      'stress':
          metrics.hasGsr || metrics.hasHeartRate ? metrics.stressLevel : null,
      'temperature_c': metrics.hasBodyTemperature ? metrics.temperatureC : null,
      'battery_pct': metrics.hasBattery ? metrics.batteryPct : null,
      'activity': metrics.activity,
      'fall_detected': metrics.fallDetected,
      'movement_detected': metrics.movementDetected,
    };
  }
}
