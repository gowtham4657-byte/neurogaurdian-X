import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../metrics/metrics.dart';

class WearableDevice {
  const WearableDevice({
    required this.id,
    required this.name,
    required this.rssi,
    required this.connectable,
    required this.likelyNeuroGuardian,
  });

  final String id;
  final String name;
  final int rssi;
  final bool connectable;
  final bool likelyNeuroGuardian;
}

/// Handles BLE connectivity and streams parsed NeuroGuardian vitals.
class BLERepository {
  BLERepository();

  static final Guid serviceUuid = Guid('0000ffe0-0000-1000-8000-00805f9b34fb');
  static final Guid metricsCharacteristicUuid = Guid(
    '0000ffe1-0000-1000-8000-00805f9b34fb',
  );
  static final Guid productionServiceUuid = Guid(
    '6e670001-b5a3-f393-e0a9-e50e24dcca9e',
  );
  static final Guid productionMetricsCharacteristicUuid = Guid(
    '6e670002-b5a3-f393-e0a9-e50e24dcca9e',
  );
  static final Guid productionCommandCharacteristicUuid = Guid(
    '6e670003-b5a3-f393-e0a9-e50e24dcca9e',
  );

  final _controller = StreamController<Metrics>.broadcast();
  final _connectionController = StreamController<String>.broadcast();
  final _devicesController = StreamController<List<WearableDevice>>.broadcast();
  final _rand = Random();

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<List<int>>? _metricsSub;
  StreamSubscription<BluetoothConnectionState>? _connectionSub;
  Timer? _reconnectTimer;
  Timer? _demoTimer;
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _commandCharacteristic;
  Metrics? _lastDemo;
  String? _lastDeviceId;
  bool _intentionalDisconnect = false;
  int _reconnectAttempt = 0;

  Stream<Metrics> get metricsStream => _controller.stream;
  Stream<String> get connectionStatus => _connectionController.stream;
  Stream<List<WearableDevice>> get discoveredDevices =>
      _devicesController.stream;

  Future<void> startDemo() async {
    await disconnect();
    _connectionController.add('Demo stream active');
    _emitDemoSample();
    _demoTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _emitDemoSample(),
    );
  }

  Future<void> startFallDemo() async {
    await disconnect();
    _connectionController.add('Fall demo active');
    _emitFallSample(activity: 'Fall detected', fallDetected: true);
    _demoTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _emitFallSample(activity: 'No movement', fallDetected: false),
    );
  }

  Future<void> startFallRecoveryDemo() async {
    await disconnect();
    _connectionController.add('Fall recovery demo active');
    var ticks = 0;
    _emitFallSample(activity: 'Fall detected', fallDetected: true);
    _demoTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      ticks += 1;
      if (ticks <= 4) {
        _emitFallSample(activity: 'No movement', fallDetected: false);
        return;
      }

      _emitMovementSample();
      if (ticks >= 7) {
        timer.cancel();
        _demoTimer = Timer.periodic(
          const Duration(seconds: 2),
          (_) => _emitDemoSample(),
        );
      }
    });
  }

  Future<void> startCriticalFallDemo() async {
    await disconnect();
    _connectionController.add('Critical fall demo active');
    _emitPreFallSample();
    var ticks = 0;
    _demoTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      ticks += 1;
      if (ticks == 1) {
        _emitCriticalFallSample();
        return;
      }
      _emitFallSample(activity: 'No movement', fallDetected: false);
    });
  }

  Future<void> startScan() async {
    _intentionalDisconnect = true;
    stop();
    await _scanSub?.cancel();
    _devicesController.add(const []);
    _connectionController.add('Scanning for ESP32 wearable...');

    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      final devices = results.map(_toWearableDevice).toList()
        ..sort((a, b) {
          if (a.likelyNeuroGuardian != b.likelyNeuroGuardian) {
            return a.likelyNeuroGuardian ? -1 : 1;
          }
          return b.rssi.compareTo(a.rssi);
        });
      _devicesController.add(devices);
    });

    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 12),
      webOptionalServices: [serviceUuid, productionServiceUuid],
      androidUsesFineLocation: true,
    );
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    await _scanSub?.cancel();
    _scanSub = null;
    _connectionController.add('Scan stopped');
  }

  Future<void> connectTo(String deviceId) async {
    await stopScan();
    _intentionalDisconnect = false;
    _lastDeviceId = deviceId;
    _reconnectAttempt = 0;
    stop();
    await _connectToDevice(deviceId, reconnecting: false);
  }

  Future<void> _connectToDevice(
    String deviceId, {
    required bool reconnecting,
  }) async {
    _connectionController.add(
      reconnecting ? 'Reconnecting to wearable...' : 'Connecting to wearable',
    );
    final device = BluetoothDevice.fromId(deviceId);
    _connectedDevice = device;
    var sawConnected = false;
    _connectionSub = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.connected) {
        sawConnected = true;
        _reconnectAttempt = 0;
        _connectionController.add('Wearable connected');
        return;
      }

      _commandCharacteristic = null;
      unawaited(_metricsSub?.cancel() ?? Future<void>.value());
      _metricsSub = null;
      _connectionController.add('Wearable disconnected');
      if (sawConnected && !_intentionalDisconnect) {
        _scheduleReconnect();
      }
    });

    await device.connect(timeout: const Duration(seconds: 12));
    try {
      await device.requestMtu(517);
    } catch (_) {
      // MTU requests are Android-only; safely ignore when unsupported.
    }
    final services = await device.discoverServices();
    final service = _findService(services);
    if (service == null) {
      throw StateError(
        'NeuroGuardian service not found. Check ESP32 BLE UUIDs.',
      );
    }
    final characteristic = _findMetricsCharacteristic(service);
    if (characteristic == null) {
      throw StateError('Metrics characteristic not found on wearable.');
    }
    _commandCharacteristic = _findCommandCharacteristic(service);

    await characteristic.setNotifyValue(true);
    _metricsSub = characteristic.onValueReceived.listen((packet) {
      final metrics = parseEsp32Packet(packet);
      if (metrics != null) _controller.add(metrics);
    });
    _connectionController.add('Wearable connected: ${device.platformName}');
  }

  void _scheduleReconnect() {
    final lastDeviceId = _lastDeviceId;
    if (_intentionalDisconnect || lastDeviceId == null) return;
    if (_reconnectTimer?.isActive ?? false) return;

    _reconnectAttempt += 1;
    final delaySeconds = min(30, 2 + (_reconnectAttempt * 2));
    _connectionController.add(
      'Wearable disconnected. Reconnecting in ${delaySeconds}s...',
    );
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () async {
      if (_intentionalDisconnect || _lastDeviceId == null) return;
      try {
        await _metricsSub?.cancel();
        await _connectionSub?.cancel();
        _metricsSub = null;
        _connectionSub = null;
        _commandCharacteristic = null;
        await _connectToDevice(lastDeviceId, reconnecting: true);
      } catch (error) {
        _connectionController.add('Reconnect failed: $error');
        _scheduleReconnect();
      }
    });
  }

  Future<bool> sendCommand(String command) async {
    final characteristic = _commandCharacteristic;
    if (characteristic == null) return false;
    try {
      await characteristic.write(
        utf8.encode(command),
        withoutResponse: characteristic.properties.writeWithoutResponse,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Metrics? parseEsp32Packet(List<int> packet) {
    final jsonMetrics = _parseJsonPacket(packet);
    if (jsonMetrics != null) return jsonMetrics;

    final textMetrics = _parseTextPacket(packet);
    if (textMetrics != null) return textMetrics;

    if (packet.length >= 16 && packet[0] == 0x4E && packet[1] == 0x47) {
      return _parseNgxBinaryPacket(packet);
    }

    if (packet.length < 9) return null;
    final data = ByteData.sublistView(Uint8List.fromList(packet));
    final timestampSeconds = data.getUint32(0, Endian.little);
    final heartRate = data.getUint8(4);
    final hrv = data.getUint8(5).toDouble();
    final stress = data.getUint8(6).clamp(0, 100).toDouble();
    final tempC = data.getInt16(7, Endian.little) / 100;
    final activityCode = packet.length > 9 ? data.getUint8(9) : 0;
    final flags = packet.length > 10 ? data.getUint8(10) : 0;
    final activity = _activityLabel(activityCode);
    final fallDetected = flags & 0x01 != 0 || activity == 'Fall detected';
    final movementDetected = flags & 0x02 != 0 ||
        (activity != 'Fall detected' && activity != 'No movement');

    return Metrics(
      timestamp: timestampSeconds == 0
          ? DateTime.now()
          : DateTime.fromMillisecondsSinceEpoch(timestampSeconds * 1000),
      heartRate: heartRate,
      hrv: hrv,
      gsrLevel: stress,
      stressLevel: stress,
      temperatureC: tempC,
      activity: activity,
      fallDetected: fallDetected,
      movementDetected: movementDetected,
    );
  }

  void stop() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _demoTimer?.cancel();
    _demoTimer = null;
    _metricsSub?.cancel();
    _metricsSub = null;
    _connectionSub?.cancel();
    _connectionSub = null;
    _commandCharacteristic = null;
  }

  Future<void> disconnect() async {
    _intentionalDisconnect = true;
    stop();
    final device = _connectedDevice;
    _connectedDevice = null;
    if (device != null && device.isConnected) {
      await device.disconnect();
    }
    _connectionController.add('Wearable disconnected');
  }

  void dispose() {
    stop();
    _scanSub?.cancel();
    _controller.close();
    _connectionController.close();
    _devicesController.close();
  }

  WearableDevice _toWearableDevice(ScanResult result) {
    final advertisedName = result.advertisementData.advName;
    final platformName = result.device.platformName;
    final name = advertisedName.isNotEmpty
        ? advertisedName
        : platformName.isNotEmpty
            ? platformName
            : 'Unknown ESP32 device';
    final searchable = '$name ${result.device.remoteId}'.toLowerCase();
    final serviceMatch = result.advertisementData.serviceUuids
            .contains(serviceUuid) ||
        result.advertisementData.serviceUuids.contains(productionServiceUuid);
    final nameMatch = searchable.contains('neuro') ||
        searchable.contains('guardian') ||
        searchable.contains('ngx') ||
        searchable.contains('esp32');

    return WearableDevice(
      id: result.device.remoteId.str,
      name: name,
      rssi: result.rssi,
      connectable: result.advertisementData.connectable,
      likelyNeuroGuardian: serviceMatch || nameMatch,
    );
  }

  BluetoothService? _findService(List<BluetoothService> services) {
    for (final service in services) {
      if (service.serviceUuid == productionServiceUuid) return service;
    }
    for (final service in services) {
      if (service.serviceUuid == serviceUuid) return service;
    }
    return null;
  }

  BluetoothCharacteristic? _findMetricsCharacteristic(
    BluetoothService service,
  ) {
    for (final characteristic in service.characteristics) {
      if (characteristic.characteristicUuid ==
          productionMetricsCharacteristicUuid) {
        return characteristic;
      }
    }
    for (final characteristic in service.characteristics) {
      if (characteristic.characteristicUuid == metricsCharacteristicUuid) {
        return characteristic;
      }
    }
    for (final characteristic in service.characteristics) {
      if (characteristic.properties.notify ||
          characteristic.properties.indicate) {
        return characteristic;
      }
    }
    return null;
  }

  BluetoothCharacteristic? _findCommandCharacteristic(
    BluetoothService service,
  ) {
    for (final characteristic in service.characteristics) {
      if (characteristic.characteristicUuid ==
          productionCommandCharacteristicUuid) {
        return characteristic;
      }
    }
    for (final characteristic in service.characteristics) {
      if (characteristic.properties.write ||
          characteristic.properties.writeWithoutResponse) {
        return characteristic;
      }
    }
    return null;
  }

  Metrics? _parseTextPacket(List<int> packet) {
    final text = utf8.decode(packet, allowMalformed: true).trim();
    if (!text.contains(',')) return null;
    final rawParts = text.split(',').map((p) => p.trim()).toList();
    final parts = rawParts.isNotEmpty && rawParts.first.toUpperCase() == 'NGX'
        ? rawParts.skip(1).toList()
        : rawParts;
    if (parts.length < 8) return null;

    final timestampSeconds = int.tryParse(parts[0]) ?? 0;
    final heartRate = int.tryParse(parts[1]);
    final spo2 = int.tryParse(parts[2]);
    final hrv = double.tryParse(parts[3]);
    final gsr = double.tryParse(parts[4]);
    final stress = double.tryParse(parts[5]);
    final temp = double.tryParse(parts[6]);
    final activityCode = int.tryParse(parts[7]) ?? 0;
    final flags = parts.length > 8 ? int.tryParse(parts[8]) ?? 0 : 0;
    final ecg = parts.length > 9 ? double.tryParse(parts[9]) : null;
    final latitude = parts.length > 10 ? double.tryParse(parts[10]) : null;
    final longitude = parts.length > 11 ? double.tryParse(parts[11]) : null;
    final gpsAccuracy = parts.length > 12 ? double.tryParse(parts[12]) : null;
    final battery = parts.length > 13 ? int.tryParse(parts[13]) : null;
    final accelX = parts.length > 14 ? double.tryParse(parts[14]) : null;
    final accelY = parts.length > 15 ? double.tryParse(parts[15]) : null;
    final accelZ = parts.length > 16 ? double.tryParse(parts[16]) : null;
    final gyroX = parts.length > 17 ? double.tryParse(parts[17]) : null;
    final gyroY = parts.length > 18 ? double.tryParse(parts[18]) : null;
    final gyroZ = parts.length > 19 ? double.tryParse(parts[19]) : null;
    final pressure = parts.length > 20 ? double.tryParse(parts[20]) : null;
    final altitude = parts.length > 21 ? double.tryParse(parts[21]) : null;
    final ppgQuality = parts.length > 22 ? double.tryParse(parts[22]) : null;
    final ecgQuality = parts.length > 23 ? double.tryParse(parts[23]) : null;
    final gsrQuality = parts.length > 24 ? double.tryParse(parts[24]) : null;
    final temperatureQuality =
        parts.length > 25 ? double.tryParse(parts[25]) : null;
    final watchFit = parts.length > 26 ? _boolFrom(parts[26]) : null;
    if (heartRate == null || stress == null || temp == null) return null;

    final activity = _activityLabel(activityCode);
    return Metrics(
      timestamp: timestampSeconds == 0
          ? DateTime.now()
          : DateTime.fromMillisecondsSinceEpoch(timestampSeconds * 1000),
      heartRate: heartRate,
      spo2: _validSpo2(spo2),
      hrv: hrv,
      gsrLevel: gsr,
      ecgMv: ecg,
      latitude: _validGps(latitude, longitude) ? latitude : null,
      longitude: _validGps(latitude, longitude) ? longitude : null,
      gpsAccuracyM: gpsAccuracy,
      batteryPct: _validBattery(battery),
      packetVersion: 2,
      accelXG: accelX,
      accelYG: accelY,
      accelZG: accelZ,
      gyroXDps: gyroX,
      gyroYDps: gyroY,
      gyroZDps: gyroZ,
      pressureHpa: pressure,
      altitudeM: altitude,
      ppgQuality: _qualityFrom(ppgQuality),
      ecgQuality: _qualityFrom(ecgQuality),
      gsrQuality: _qualityFrom(gsrQuality),
      temperatureQuality: _qualityFrom(temperatureQuality),
      watchFit: watchFit,
      skinContact: watchFit,
      sensorFlags: flags,
      stressLevel: stress.clamp(0, 100).toDouble(),
      temperatureC: temp,
      activity: activity,
      fallDetected: flags & 0x01 != 0 || activity == 'Fall detected',
      movementDetected: flags & 0x02 != 0 ||
          (activity != 'Fall detected' && activity != 'No movement'),
    );
  }

  Metrics? _parseJsonPacket(List<int> packet) {
    final text = utf8.decode(packet, allowMalformed: true).trim();
    if (!text.startsWith('{')) return null;

    try {
      final decoded = json.decode(text);
      if (decoded is! Map) return null;

      final heartRate = _intFrom(
        decoded['hr'] ?? decoded['heart_rate'] ?? decoded['heartRate'],
      );
      final spo2 = _intFrom(decoded['sp'] ?? decoded['spo2']);
      final hrv = _doubleFrom(decoded['hrv']);
      final gsr = _doubleFrom(decoded['gsr'] ?? decoded['gs']);
      final stress = _doubleFrom(decoded['st'] ?? decoded['stress']);
      final temp = _doubleFrom(
        decoded['tp'] ?? decoded['temperature'] ?? decoded['temp'],
      );
      final activityCode = _intFrom(decoded['ac'] ?? decoded['activity_code']);
      final flags = _intFrom(decoded['flags'] ?? decoded['fl']) ?? 0;
      final rawEvent = (decoded['event'] ??
              decoded['e'] ??
              decoded['signal'] ??
              decoded['type'] ??
              decoded['status'] ??
              '')
          .toString()
          .toLowerCase()
          .trim();
      final fallEventRaw =
          decoded['ev'] ?? decoded['fall'] ?? decoded['fall_detected'];
      final fallEvent =
          _intFrom(fallEventRaw) ?? (_boolFrom(fallEventRaw) == true ? 1 : 0);
      final normalizedEvent = _normalizeEvent(rawEvent);
      final criticalEvent = normalizedEvent == 'critical_fall' ||
          rawEvent == 'critical' ||
          flags & 0x08 != 0 ||
          _boolFrom(decoded['critical']) == true;
      final eventFallDetected = normalizedEvent == 'fall_detected' ||
          rawEvent == 'fall' ||
          criticalEvent ||
          fallEvent == 1;
      final noMovementEvent = normalizedEvent == 'no_movement' ||
          rawEvent == 'stillness' ||
          _boolFrom(decoded['no_movement']) == true;
      final movementOverride = _boolFrom(
        decoded['mv'] ?? decoded['movement'] ?? decoded['movement_detected'],
      );
      final ecg =
          _doubleFrom(decoded['ecg'] ?? decoded['eg'] ?? decoded['ecgMv']);
      final latitude =
          _doubleFrom(decoded['lat'] ?? decoded['la'] ?? decoded['latitude']);
      final longitude =
          _doubleFrom(decoded['lon'] ?? decoded['lo'] ?? decoded['lng']);
      final gpsAccuracy = _doubleFrom(
        decoded['gp'] ??
            decoded['gps'] ??
            decoded['gpsAccuracyM'] ??
            decoded['accuracy'],
      );
      final battery = _intFrom(decoded['bt'] ?? decoded['battery']);
      final timestamp =
          _timestampFrom(decoded['ts'] ?? decoded['t'] ?? decoded['timestamp']);
      final packetVersion = _intFrom(
            decoded['v'] ??
                decoded['packetVersion'] ??
                decoded['packet_version'],
          ) ??
          1;
      final accelX =
          _doubleFrom(decoded['ax'] ?? decoded['accX'] ?? decoded['accelX']);
      final accelY =
          _doubleFrom(decoded['ay'] ?? decoded['accY'] ?? decoded['accelY']);
      final accelZ =
          _doubleFrom(decoded['az'] ?? decoded['accZ'] ?? decoded['accelZ']);
      final gyroX = _doubleFrom(decoded['gx'] ?? decoded['gyroX']);
      final gyroY = _doubleFrom(decoded['gy'] ?? decoded['gyroY']);
      final gyroZ = _doubleFrom(decoded['gz'] ?? decoded['gyroZ']);
      final pressure = _doubleFrom(
          decoded['pr'] ?? decoded['pressure'] ?? decoded['pressureHpa']);
      final altitude =
          _doubleFrom(decoded['al'] ?? decoded['alt'] ?? decoded['altitude']);
      final ppgQuality = _qualityFrom(
        decoded['pq'] ?? decoded['ppgQuality'] ?? decoded['ppg_quality'],
      );
      final ecgQuality = _qualityFrom(
        decoded['eq'] ?? decoded['ecgQuality'] ?? decoded['ecg_quality'],
      );
      final gsrQuality = _qualityFrom(
        decoded['gq'] ?? decoded['gsrQuality'] ?? decoded['gsr_quality'],
      );
      final temperatureQuality = _qualityFrom(
        decoded['tq'] ??
            decoded['temperatureQuality'] ??
            decoded['temperature_quality'],
      );
      final skinContact = _boolFrom(
        decoded['ct'] ?? decoded['skinContact'] ?? decoded['skin_contact'],
      );
      final watchFit = _boolFrom(decoded['wf'] ?? decoded['watchFit']);

      if ((heartRate == null || stress == null || temp == null) &&
          !eventFallDetected &&
          !noMovementEvent) {
        return null;
      }

      final activity = _jsonActivityLabel(
        activityCode,
        decoded['activity']?.toString(),
      );
      final fallDetected =
          eventFallDetected || flags & 0x01 != 0 || activity == 'Fall detected';
      final movementDetected = movementOverride ??
          (!noMovementEvent &&
              (flags & 0x02 != 0 ||
                  (!fallDetected && activity != 'No movement')));

      return Metrics(
        timestamp: timestamp,
        heartRate: heartRate ?? 0,
        spo2: _validSpo2(spo2),
        hrv: hrv,
        gsrLevel: gsr,
        ecgMv: ecg,
        latitude: _validGps(latitude, longitude) ? latitude : null,
        longitude: _validGps(latitude, longitude) ? longitude : null,
        gpsAccuracyM: gpsAccuracy,
        batteryPct: _validBattery(battery),
        packetVersion: packetVersion,
        accelXG: accelX,
        accelYG: accelY,
        accelZG: accelZ,
        gyroXDps: gyroX,
        gyroYDps: gyroY,
        gyroZDps: gyroZ,
        pressureHpa: pressure,
        altitudeM: altitude,
        ppgQuality: ppgQuality,
        ecgQuality: ecgQuality,
        gsrQuality: gsrQuality,
        temperatureQuality: temperatureQuality,
        watchFit: watchFit,
        skinContact: skinContact,
        sensorFlags: flags,
        stressLevel: (stress ?? 0).clamp(0, 100).toDouble(),
        temperatureC: temp ?? 0,
        activity: criticalEvent
            ? 'Critical fall'
            : fallDetected
                ? 'Fall detected'
                : noMovementEvent
                    ? 'No movement'
                    : activity,
        fallDetected: fallDetected,
        movementDetected: movementDetected,
      );
    } catch (_) {
      return null;
    }
  }

  Metrics? _parseNgxBinaryPacket(List<int> packet) {
    final data = ByteData.sublistView(Uint8List.fromList(packet));
    final timestampSeconds = data.getUint32(3, Endian.little);
    final heartRate = data.getUint8(7);
    final spo2 = data.getUint8(8);
    final hrv = data.getUint8(9).toDouble();
    final gsr = data.getUint8(10).toDouble();
    final stress = data.getUint8(11).clamp(0, 100).toDouble();
    final tempC = data.getInt16(12, Endian.little) / 100;
    final activityCode = data.getUint8(14);
    final flags = data.getUint8(15);
    final ecgMv =
        packet.length >= 18 ? data.getInt16(16, Endian.little) / 1000 : null;
    final latitude = packet.length >= 28
        ? data.getInt32(18, Endian.little) / 10000000
        : null;
    final longitude = packet.length >= 28
        ? data.getInt32(22, Endian.little) / 10000000
        : null;
    final gpsAccuracyM =
        packet.length >= 28 ? data.getUint16(26, Endian.little) / 10 : null;
    final activity = _activityLabel(activityCode);

    return Metrics(
      timestamp: timestampSeconds == 0
          ? DateTime.now()
          : DateTime.fromMillisecondsSinceEpoch(timestampSeconds * 1000),
      heartRate: heartRate,
      spo2: _validSpo2(spo2),
      hrv: hrv,
      gsrLevel: gsr,
      ecgMv: ecgMv,
      latitude: _validGps(latitude, longitude) ? latitude : null,
      longitude: _validGps(latitude, longitude) ? longitude : null,
      gpsAccuracyM: gpsAccuracyM,
      batteryPct: packet.length >= 29 ? _validBattery(data.getUint8(28)) : null,
      sensorFlags: flags,
      stressLevel: stress,
      temperatureC: tempC,
      activity: activity,
      fallDetected: flags & 0x01 != 0 || activity == 'Fall detected',
      movementDetected: flags & 0x02 != 0 ||
          (activity != 'Fall detected' && activity != 'No movement'),
    );
  }

  bool _validGps(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) return false;
    if (latitude == 0 && longitude == 0) return false;
    return latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  int? _validSpo2(int? spo2) {
    if (spo2 == null || spo2 < 50 || spo2 > 100) return null;
    return spo2;
  }

  int? _validBattery(int? battery) {
    if (battery == null || battery < 0 || battery > 100) return null;
    return battery;
  }

  double? _qualityFrom(Object? value) {
    final raw = value is num ? value.toDouble() : _doubleFrom(value);
    if (raw == null) return null;
    final normalized = raw > 1 ? raw / 100 : raw;
    return normalized.clamp(0, 1).toDouble();
  }

  String _normalizeEvent(String raw) {
    switch (raw) {
      case 'c':
      case 'critical':
      case 'critical_fall':
        return 'critical_fall';
      case 'f':
      case 'fall':
      case 'fall_detected':
        return 'fall_detected';
      case 'm':
      case 'still':
      case 'stillness':
      case 'no_movement':
        return 'no_movement';
      default:
        return raw;
    }
  }

  int? _intFrom(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '');
  }

  double? _doubleFrom(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  bool? _boolFrom(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().toLowerCase();
    if (text == 'true' || text == 'yes' || text == '1') return true;
    if (text == 'false' || text == 'no' || text == '0') return false;
    return null;
  }

  DateTime _timestampFrom(Object? value) {
    final raw = _intFrom(value);
    if (raw == null || raw <= 0) return DateTime.now();
    if (raw > 1000000000000) {
      return DateTime.fromMillisecondsSinceEpoch(raw);
    }
    return DateTime.fromMillisecondsSinceEpoch(raw * 1000);
  }

  void _emitDemoSample() {
    final previous = _lastDemo;
    final activity = _activityLabel(_rand.nextInt(3));
    final next = Metrics(
      timestamp: DateTime.now(),
      heartRate: _drift(
        previous?.heartRate ?? 82,
        minValue: 62,
        maxValue: 126,
        step: 8,
      ).round(),
      spo2: _drift(previous?.spo2 ?? 97, minValue: 92, maxValue: 100, step: 2)
          .round(),
      hrv: _drift(previous?.hrv ?? 48, minValue: 18, maxValue: 82, step: 8),
      gsrLevel: _drift(
        previous?.gsrLevel ?? 38,
        minValue: 8,
        maxValue: 92,
        step: 10,
      ),
      ecgMv: _drift(previous?.ecgMv ?? 0.72,
          minValue: 0.2, maxValue: 1.4, step: 0.08),
      stressLevel: _drift(
        previous?.stressLevel ?? 42,
        minValue: 12,
        maxValue: 88,
        step: 12,
      ),
      temperatureC: _drift(
        previous?.temperatureC ?? 36.7,
        minValue: 35.9,
        maxValue: 38.6,
        step: 0.25,
      ),
      activity: activity,
      movementDetected: true,
      batteryPct: 86,
      packetVersion: 2,
      accelXG: 0.03,
      accelYG: -0.02,
      accelZG: 0.99,
      gyroXDps: 0.4,
      gyroYDps: 0.2,
      gyroZDps: 0.1,
      pressureHpa: 1008.6,
      altitudeM: 760,
      ppgQuality: 0.86,
      ecgQuality: 0.78,
      gsrQuality: 0.82,
      temperatureQuality: 0.74,
      watchFit: true,
      skinContact: true,
    );
    _lastDemo = next;
    _controller.add(next);
  }

  void _emitFallSample({
    required String activity,
    required bool fallDetected,
  }) {
    final previous = _lastDemo;
    final next = Metrics(
      timestamp: DateTime.now(),
      heartRate: _drift(
        previous?.heartRate ?? 104,
        minValue: 92,
        maxValue: 132,
        step: 6,
      ).round(),
      spo2: _drift(previous?.spo2 ?? 94, minValue: 88, maxValue: 98, step: 2)
          .round(),
      hrv: _drift(previous?.hrv ?? 28, minValue: 12, maxValue: 42, step: 5),
      gsrLevel: _drift(
        previous?.gsrLevel ?? 82,
        minValue: 70,
        maxValue: 100,
        step: 5,
      ),
      ecgMv: _drift(previous?.ecgMv ?? 1.1,
          minValue: 0.4, maxValue: 1.8, step: 0.12),
      stressLevel: _drift(
        previous?.stressLevel ?? 82,
        minValue: 74,
        maxValue: 98,
        step: 6,
      ),
      temperatureC: _drift(
        previous?.temperatureC ?? 37.2,
        minValue: 36.4,
        maxValue: 38.2,
        step: 0.15,
      ),
      activity: activity,
      fallDetected: fallDetected,
      movementDetected: false,
      batteryPct: previous?.batteryPct ?? 84,
      packetVersion: 2,
      accelXG: 2.7,
      accelYG: 0.4,
      accelZG: 1.1,
      gyroXDps: 180,
      gyroYDps: 82,
      gyroZDps: 35,
      ppgQuality: 0.62,
      ecgQuality: 0.58,
      gsrQuality: 0.78,
      temperatureQuality: 0.70,
      watchFit: true,
      skinContact: true,
    );
    _lastDemo = next;
    _controller.add(next);
  }

  void _emitMovementSample() {
    final previous = _lastDemo;
    final next = Metrics(
      timestamp: DateTime.now(),
      heartRate: _drift(
        previous?.heartRate ?? 94,
        minValue: 72,
        maxValue: 108,
        step: 5,
      ).round(),
      spo2: _drift(previous?.spo2 ?? 97, minValue: 94, maxValue: 100, step: 2)
          .round(),
      hrv: _drift(previous?.hrv ?? 45, minValue: 30, maxValue: 76, step: 8),
      gsrLevel: _drift(
        previous?.gsrLevel ?? 46,
        minValue: 18,
        maxValue: 72,
        step: 8,
      ),
      ecgMv: _drift(previous?.ecgMv ?? 0.68,
          minValue: 0.2, maxValue: 1.2, step: 0.08),
      stressLevel: _drift(
        previous?.stressLevel ?? 48,
        minValue: 20,
        maxValue: 66,
        step: 8,
      ),
      temperatureC: _drift(
        previous?.temperatureC ?? 36.8,
        minValue: 36.0,
        maxValue: 37.5,
        step: 0.2,
      ),
      activity: 'Walking',
      fallDetected: false,
      movementDetected: true,
      batteryPct: previous?.batteryPct ?? 84,
      packetVersion: 2,
      accelXG: 0.42,
      accelYG: 0.18,
      accelZG: 0.92,
      gyroXDps: 18,
      gyroYDps: 8,
      gyroZDps: 5,
      ppgQuality: 0.82,
      ecgQuality: 0.72,
      gsrQuality: 0.76,
      temperatureQuality: 0.75,
      watchFit: true,
      skinContact: true,
    );
    _lastDemo = next;
    _controller.add(next);
  }

  void _emitPreFallSample() {
    final next = Metrics(
      timestamp: DateTime.now(),
      heartRate: 112,
      spo2: 95,
      hrv: 32,
      gsrLevel: 74,
      ecgMv: 1.02,
      stressLevel: 72,
      temperatureC: 37.1,
      activity: 'Walking',
      fallDetected: false,
      movementDetected: true,
      batteryPct: 84,
      packetVersion: 2,
      accelXG: 0.12,
      accelYG: 0.18,
      accelZG: 1.02,
      gyroXDps: 6,
      gyroYDps: 4,
      gyroZDps: 3,
      ppgQuality: 0.76,
      ecgQuality: 0.70,
      gsrQuality: 0.80,
      temperatureQuality: 0.72,
      watchFit: true,
      skinContact: true,
    );
    _lastDemo = next;
    _controller.add(next);
  }

  void _emitCriticalFallSample() {
    final next = Metrics(
      timestamp: DateTime.now(),
      heartRate: 76,
      spo2: 89,
      hrv: 16,
      gsrLevel: 96,
      ecgMv: 1.45,
      stressLevel: 96,
      temperatureC: 37.3,
      activity: 'Fall detected',
      fallDetected: true,
      movementDetected: false,
      batteryPct: 84,
      packetVersion: 2,
      accelXG: 2.95,
      accelYG: 0.55,
      accelZG: 0.95,
      gyroXDps: 210,
      gyroYDps: 96,
      gyroZDps: 44,
      ppgQuality: 0.58,
      ecgQuality: 0.55,
      gsrQuality: 0.82,
      temperatureQuality: 0.69,
      watchFit: true,
      skinContact: true,
    );
    _lastDemo = next;
    _controller.add(next);
  }

  double _drift(
    num value, {
    required num minValue,
    required num maxValue,
    required num step,
  }) {
    final next = value + (_rand.nextDouble() * step * 2) - step;
    return next.clamp(minValue, maxValue).toDouble();
  }

  String _activityLabel(int code) {
    switch (code) {
      case 1:
        return 'Walking';
      case 2:
        return 'Running';
      case 3:
        return 'Fall detected';
      case 4:
        return 'No movement';
      default:
        return 'Resting';
    }
  }

  String _jsonActivityLabel(int? code, String? rawActivity) {
    final raw = rawActivity?.trim();
    if (raw != null && raw.isNotEmpty) {
      final normalized = raw.toLowerCase();
      if (normalized.contains('fall')) return 'Fall detected';
      if (normalized.contains('sleep')) return 'Sleeping';
      if (normalized.contains('run')) return 'Running';
      if (normalized.contains('walk')) return 'Walking';
      if (normalized.contains('active')) return 'Active';
      if (normalized.contains('still') || normalized.contains('no movement')) {
        return 'No movement';
      }
      return raw[0].toUpperCase() + raw.substring(1);
    }

    switch (code) {
      case 1:
        return 'Walking';
      case 2:
        return 'Running';
      case 3:
        return 'Fall detected';
      case 4:
        return 'No movement';
      case 5:
        return 'Sleeping';
      default:
        return 'Resting';
    }
  }
}
