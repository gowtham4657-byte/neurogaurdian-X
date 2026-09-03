class MedicalFacility {
  const MedicalFacility({
    required this.name,
    required this.address,
    this.phone,
    this.latitude,
    this.longitude,
    this.mapsUri,
  });

  factory MedicalFacility.fromMap(Map<String, dynamic> raw) {
    final displayName = raw['displayName'];
    final location = raw['location'];
    return MedicalFacility(
      name: displayName is Map
          ? displayName['text'] as String? ?? 'Medical facility'
          : raw['name'] as String? ?? 'Medical facility',
      address: raw['formattedAddress'] as String? ??
          raw['address'] as String? ??
          'Address unavailable',
      phone: raw['nationalPhoneNumber'] as String? ?? raw['phone'] as String?,
      latitude: location is Map
          ? (location['latitude'] as num?)?.toDouble()
          : (raw['latitude'] as num?)?.toDouble(),
      longitude: location is Map
          ? (location['longitude'] as num?)?.toDouble()
          : (raw['longitude'] as num?)?.toDouble(),
      mapsUri: raw['googleMapsUri'] as String? ?? raw['mapsUri'] as String?,
    );
  }

  final String name;
  final String address;
  final String? phone;
  final double? latitude;
  final double? longitude;
  final String? mapsUri;

  String get compactLine {
    final parts = [
      name,
      address,
      if (phone != null && phone!.trim().isNotEmpty) 'Phone $phone',
      if (mapsUri != null && mapsUri!.trim().isNotEmpty) mapsUri!,
    ];
    return parts.join(' - ');
  }

  Map<String, Object?> toMap() {
    return {
      'name': name,
      'address': address,
      'phone': phone,
      'latitude': latitude,
      'longitude': longitude,
      'mapsUri': mapsUri,
    };
  }
}
