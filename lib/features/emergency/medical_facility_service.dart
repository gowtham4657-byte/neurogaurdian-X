import 'dart:convert';

import 'package:http/http.dart' as http;

import 'medical_facility.dart';

class MedicalFacilityService {
  const MedicalFacilityService();

  static const backendTimeout = Duration(seconds: 8);
  static const googlePlacesApiKey = String.fromEnvironment(
    'NGX_GOOGLE_PLACES_API_KEY',
    defaultValue: '',
  );

  Future<List<MedicalFacility>> nearbyHospitals({
    required double latitude,
    required double longitude,
    String backendUrl = '',
    String backendToken = '',
  }) async {
    final backendFacilities = await _nearbyHospitalsFromBackend(
      latitude: latitude,
      longitude: longitude,
      backendUrl: backendUrl,
      backendToken: backendToken,
    );
    if (backendFacilities != null) return backendFacilities;

    if (googlePlacesApiKey.trim().isEmpty) return const [];
    return _nearbyHospitalsFromGoogle(
      latitude: latitude,
      longitude: longitude,
    );
  }

  Future<List<MedicalFacility>?> _nearbyHospitalsFromBackend({
    required double latitude,
    required double longitude,
    required String backendUrl,
    required String backendToken,
  }) async {
    final normalizedBackend = backendUrl.trim();
    if (normalizedBackend.isEmpty) return null;

    try {
      final response = await http
          .post(
            _endpointFor(normalizedBackend, '/medical-facilities/nearby'),
            headers: {
              'Content-Type': 'application/json',
              if (backendToken.trim().isNotEmpty)
                'Authorization': 'Bearer ${backendToken.trim()}',
            },
            body: json.encode({
              'latitude': latitude,
              'longitude': longitude,
              'max_results': 3,
            }),
          )
          .timeout(backendTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final decoded = json.decode(response.body);
      final list = _extractFacilityList(decoded);
      return list
          .whereType<Map>()
          .map((item) => MedicalFacility.fromMap(item.cast<String, dynamic>()))
          .take(3)
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<List<MedicalFacility>> _nearbyHospitalsFromGoogle({
    required double latitude,
    required double longitude,
  }) async {
    if (googlePlacesApiKey.trim().isEmpty) return const [];

    final response = await http.post(
      Uri.parse('https://places.googleapis.com/v1/places:searchNearby'),
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': googlePlacesApiKey,
        'X-Goog-FieldMask':
            'places.displayName,places.formattedAddress,places.location,places.nationalPhoneNumber,places.googleMapsUri',
      },
      body: json.encode({
        'includedTypes': ['hospital'],
        'maxResultCount': 3,
        'rankPreference': 'DISTANCE',
        'locationRestriction': {
          'circle': {
            'center': {
              'latitude': latitude,
              'longitude': longitude,
            },
            'radius': 10000.0,
          },
        },
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Google Places failed: HTTP ${response.statusCode}');
    }

    final decoded = json.decode(response.body);
    if (decoded is! Map || decoded['places'] is! List) return const [];
    return (decoded['places'] as List)
        .whereType<Map>()
        .map((item) => MedicalFacility.fromMap(item.cast<String, dynamic>()))
        .take(3)
        .toList();
  }

  Uri _endpointFor(String backendUrl, String path) {
    final normalized = backendUrl.endsWith('/')
        ? backendUrl.substring(0, backendUrl.length - 1)
        : backendUrl;
    return Uri.parse('$normalized$path');
  }

  List _extractFacilityList(Object? decoded) {
    if (decoded is List) return decoded;
    if (decoded is! Map) return const [];
    final direct = decoded['facilities'] ?? decoded['medical_facilities'];
    if (direct is List) return direct;
    final data = decoded['data'];
    if (data is Map) {
      final nested = data['facilities'] ?? data['medical_facilities'];
      if (nested is List) return nested;
    }
    return const [];
  }
}
