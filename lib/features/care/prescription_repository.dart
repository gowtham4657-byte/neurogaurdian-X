import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

final prescriptionsProvider = StateNotifierProvider<PrescriptionController,
    AsyncValue<List<DoctorPrescription>>>(
  (ref) => PrescriptionController(),
);

class DoctorPrescription {
  const DoctorPrescription({
    required this.id,
    required this.medicine,
    required this.dose,
    required this.timing,
    required this.doctor,
    required this.addedAt,
  });

  factory DoctorPrescription.fromMap(Map raw) {
    return DoctorPrescription(
      id: raw['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      medicine: raw['medicine'] as String? ?? '',
      dose: raw['dose'] as String? ?? '',
      timing: raw['timing'] as String? ?? '',
      doctor: raw['doctor'] as String? ?? 'Doctor',
      addedAt: DateTime.fromMillisecondsSinceEpoch(
        raw['addedAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  final String id;
  final String medicine;
  final String dose;
  final String timing;
  final String doctor;
  final DateTime addedAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'medicine': medicine,
      'dose': dose,
      'timing': timing,
      'doctor': doctor,
      'addedAt': addedAt.millisecondsSinceEpoch,
    };
  }
}

class PrescriptionController
    extends StateNotifier<AsyncValue<List<DoctorPrescription>>> {
  PrescriptionController() : super(const AsyncValue.loading()) {
    reload();
  }

  static const _boxName = 'doctor_prescriptions';

  Box<Map>? _box;

  Future<void> reload() async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await _readAll());
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> add({
    required String medicine,
    required String dose,
    required String timing,
    required String doctor,
  }) async {
    final box = await _openBox();
    final prescription = DoctorPrescription(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      medicine: medicine.trim(),
      dose: dose.trim(),
      timing: timing.trim(),
      doctor: doctor.trim().isEmpty ? 'Doctor' : doctor.trim(),
      addedAt: DateTime.now(),
    );
    await box.put(prescription.id, prescription.toMap());
    state = AsyncValue.data(await _readAll());
  }

  Future<void> remove(String id) async {
    final box = await _openBox();
    await box.delete(id);
    state = AsyncValue.data(await _readAll());
  }

  Future<List<DoctorPrescription>> _readAll() async {
    final box = await _openBox();
    final items = box.values
        .map(DoctorPrescription.fromMap)
        .where((item) => item.medicine.isNotEmpty)
        .toList()
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return items;
  }

  Future<Box<Map>> _openBox() async {
    return _box ??= await Hive.openBox<Map>(_boxName);
  }
}
