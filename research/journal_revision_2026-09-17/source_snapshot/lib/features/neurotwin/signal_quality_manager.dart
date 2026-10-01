import 'dart:math' as math;

import '../metrics/metrics.dart';
import 'neurotwin_models.dart';

class SignalQualityManager {
  const SignalQualityManager();

  SensorQuality evaluate(Metrics? metrics) {
    if (metrics == null) {
      return const SensorQuality(
        ppg: 0,
        ecg: 0,
        gsr: 0,
        temperature: 0,
        motion: 0,
        gps: 0,
        overall: 0,
        watchFit: false,
        notes: ['Waiting for live watch signal.'],
      );
    }

    final motion = _motionQuality(metrics);
    final ppg = metrics.ppgQuality ?? _estimatedPpgQuality(metrics, motion);
    final ecg = metrics.ecgQuality ?? _estimatedEcgQuality(metrics, motion);
    final gsr = metrics.gsrQuality ?? _estimatedGsrQuality(metrics);
    final temp =
        metrics.temperatureQuality ?? _estimatedTemperatureQuality(metrics);
    final gps = metrics.hasWatchGps ? 0.9 : 0.45;
    final watchFit = metrics.watchFit ??
        metrics.skinContact ??
        (math.max(math.max(ppg, ecg), gsr) >= 0.42);
    final values = [ppg, ecg, gsr, temp, motion]
        .map((v) => v.clamp(0, 1).toDouble())
        .toList();
    final overall = values.reduce((a, b) => a + b) / values.length;

    return SensorQuality(
      ppg: ppg.clamp(0, 1).toDouble(),
      ecg: ecg.clamp(0, 1).toDouble(),
      gsr: gsr.clamp(0, 1).toDouble(),
      temperature: temp.clamp(0, 1).toDouble(),
      motion: motion.clamp(0, 1).toDouble(),
      gps: gps,
      overall: overall.clamp(0, 1).toDouble(),
      watchFit: watchFit,
      notes: _notes(metrics, ppg, ecg, gsr, temp, motion, watchFit),
    );
  }

  double _estimatedPpgQuality(Metrics m, double motionQuality) {
    if (m.hasHeartRate && m.hasSpo2) return 0.62 + motionQuality * 0.28;
    if (m.hasHeartRate || m.hasSpo2) return 0.42 + motionQuality * 0.18;
    return 0.12;
  }

  double _estimatedEcgQuality(Metrics m, double motionQuality) {
    if (!m.hasEcg) return 0.08;
    final clippingPenalty = m.ecgMv!.abs() > 2.2 ? 0.25 : 0.0;
    return (0.72 + motionQuality * 0.18 - clippingPenalty).clamp(0, 1);
  }

  double _estimatedGsrQuality(Metrics m) {
    if (!m.hasGsr) return 0.08;
    if (m.gsrLevel! <= 2 || m.gsrLevel! >= 98) return 0.36;
    return 0.78;
  }

  double _estimatedTemperatureQuality(Metrics m) {
    if (!m.hasBodyTemperature) return 0.08;
    if (m.temperatureC < 34 || m.temperatureC > 40) return 0.44;
    return 0.76;
  }

  double _motionQuality(Metrics m) {
    final accel = m.accelerationMagnitudeG;
    final hasMotion = m.hasAccelerometer || m.hasGyroscope;
    if (!hasMotion) return m.movementDetected ? 0.58 : 0.64;
    if (m.fallDetected) return 0.72;
    if (accel != null && (accel < 0.2 || accel > 5.0)) return 0.35;
    return 0.86;
  }

  List<String> _notes(
    Metrics m,
    double ppg,
    double ecg,
    double gsr,
    double temp,
    double motion,
    bool watchFit,
  ) {
    final notes = <String>[];
    if (!watchFit) {
      notes.add('Watch contact looks weak. Tighten the band.');
    }
    if (ppg < 0.45) {
      notes.add('PPG/SpO2 quality is low, so pulse readings are limited.');
    }
    if (ecg < 0.45) {
      notes.add('ECG contact is weak or noisy, so ECG risk is reduced.');
    }
    if (gsr < 0.45) {
      notes.add('GSR contact is weak, so stress confidence is reduced.');
    }
    if (temp < 0.45) notes.add('Temperature contact is not reliable yet.');
    if (motion < 0.45) notes.add('Motion sensor quality is limited.');
    if (m.hasWatchGps) {
      notes.add('Watch GPS is available for SOS.');
    } else {
      notes.add('Watch GPS unavailable; phone GPS will be used for SOS.');
    }
    if (notes.isEmpty) {
      notes.add('Signals are usable for wellness risk estimation.');
    }
    return notes.take(5).toList();
  }
}
