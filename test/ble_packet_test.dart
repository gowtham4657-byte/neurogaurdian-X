import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:neuroguardian_app/features/ble/ble_repository.dart';

void main() {
  test('parses watch GPS from NeuroGuardian binary BLE packet', () {
    final repo = BLERepository();
    addTearDown(repo.dispose);

    final bytes = Uint8List(28);
    final data = ByteData.sublistView(bytes);
    bytes[0] = 0x4E;
    bytes[1] = 0x47;
    bytes[2] = 1;
    data.setUint32(3, 120, Endian.little);
    bytes[7] = 82;
    bytes[8] = 97;
    bytes[9] = 48;
    bytes[10] = 35;
    bytes[11] = 40;
    data.setInt16(12, 3670, Endian.little);
    bytes[14] = 0;
    bytes[15] = 0x02;
    data.setInt16(16, 720, Endian.little);
    data.setInt32(18, 286139000, Endian.little);
    data.setInt32(22, 772090000, Endian.little);
    data.setUint16(26, 123, Endian.little);

    final metrics = repo.parseEsp32Packet(bytes);

    expect(metrics?.latitude, closeTo(28.6139, 0.00001));
    expect(metrics?.longitude, closeTo(77.209, 0.00001));
    expect(metrics?.gpsAccuracyM, closeTo(12.3, 0.01));
  });

  test('parses watch GPS from CSV BLE packet', () {
    final repo = BLERepository();
    addTearDown(repo.dispose);

    const packet = 'NGX,120,82,97,48,35,40,36.7,0,2,0.72,28.6139,77.2090,12.3';
    final metrics = repo.parseEsp32Packet(packet.codeUnits);

    expect(metrics?.latitude, closeTo(28.6139, 0.00001));
    expect(metrics?.longitude, closeTo(77.209, 0.00001));
    expect(metrics?.gpsAccuracyM, closeTo(12.3, 0.01));
  });

  test('parses production JSON BLE packet with battery and fall event', () {
    final repo = BLERepository();
    addTearDown(repo.dispose);

    const packet = '{"ts":120,"hr":76,"sp":96,"hrv":42,"gsr":55,"tp":36.8,'
        '"st":58,"ac":3,"activity":"Fall detected","flags":5,'
        '"mv":0,"bt":87,"ecg":0.71,"lat":28.6139,"lon":77.209,'
        '"gps":9.4}';
    final metrics = repo.parseEsp32Packet(packet.codeUnits);

    expect(metrics?.fallDetected, isTrue);
    expect(metrics?.movementDetected, isFalse);
    expect(metrics?.batteryPct, 87);
    expect(metrics?.spo2, 96);
    expect(metrics?.latitude, closeTo(28.6139, 0.00001));
  });

  test('parses event-only fall_detected BLE signal', () {
    final repo = BLERepository();
    addTearDown(repo.dispose);

    const packet = '{"type":"fall_detected","movement_detected":false}';
    final metrics = repo.parseEsp32Packet(packet.codeUnits);

    expect(metrics?.fallDetected, isTrue);
    expect(metrics?.movementDetected, isFalse);
    expect(metrics?.activity, 'Fall detected');
    expect(metrics?.sensorQualityLabel, 'Motion-only alert');
  });

  test('parses critical fall BLE signal for immediate SOS', () {
    final repo = BLERepository();
    addTearDown(repo.dispose);

    const packet = '{"event":"critical_fall","hr":61,"st":95,"tp":36.5}';
    final metrics = repo.parseEsp32Packet(packet.codeUnits);

    expect(metrics?.fallDetected, isTrue);
    expect(metrics?.activity, 'Critical fall');
  });
}
