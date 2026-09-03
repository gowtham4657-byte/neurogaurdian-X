# NeuroGuardian X PhysioNet Model Training Plan

This document maps the requested PhysioNet datasets to a safe, real-world
training path for NeuroGuardian X. The current app uses rule-based risk
detection; these datasets should be used to train and validate future models
offline before any public medical claims.

## Dataset roles

| Dataset | Use in NeuroGuardian X | Notes |
| --- | --- | --- |
| MIT-BIH Arrhythmia Database | ECG rhythm pretraining and arrhythmia evaluation | 48 half-hour, two-channel ECG records with cardiologist beat annotations. |
| Sudden Cardiac Death Holter Database | Serious ECG risk research and emergency-pattern validation | Large Holter ECG dataset; use for research signals, not direct wrist diagnosis claims. |
| Wearable Device Dataset from Induced Stress and Structured Exercise Sessions | Stress/exercise classifier using BVP, activity, skin temperature, and EDA | Closest match to watch-style stress and exercise signals. |
| Wearable Exam Stress Dataset | Real-world stress trend validation using E4 HR, temperature, accelerometer, EDA, BVP, IBI | Useful for stress alerts outside the lab. |

## Training pipeline

1. Download datasets only after license review and storage approval.
2. Convert ECG records with WFDB into beat windows and rhythm labels.
3. Convert wearable records into aligned one-second windows matching app fields:
   HR, SpO2 if available, HRV/IBI, EDA/GSR, skin/body temperature, movement, and fall/no-movement state.
4. Train separate models first:
   - ECG rhythm model for arrhythmia-like patterns.
   - Stress/exercise model from EDA/BVP/temperature/motion.
   - Fall/no-movement filter from watch accelerometer data collected by our own prototype.
5. Calibrate thresholds against real watch hardware because wrist signals differ from clinical Holter ECG.
6. Export only small, explainable outputs to the app:
   - `cardiac_risk`
   - `stress_index`
   - `oxygen_risk`
   - `fall_confidence`
   - `sensor_quality`
7. Validate on held-out users and real fall-recovery scenarios before enabling auto-SOS by default.

## Safety rules for release

- Do not call this a heart attack diagnosis system.
- Use "AI risk detection" or "risk support" until clinically validated.
- Always show emergency guidance for serious patterns.
- Home remedies and exercise suggestions are allowed only for minor patterns.
- Store raw health data only with consent, encryption, and a deletion path.
- Test false negatives and false positives with real sensors before society use.

## App integration target

The Flutter app should keep the current rule-based layer as the safety fallback.
When an offline or backend model is ready, it should output risk scores into
`riskScoresProvider` while preserving the 30-second fall timer and manual
guardian SOS path.

## Firmware data needed

The ESP32 watch should stream stable JSON every 1 second:

```json
{
  "event": "none",
  "hr": 72,
  "sp": 98,
  "hrv": 45,
  "gsr": 30,
  "tp": 36.7,
  "st": 34,
  "ac": 0,
  "activity": "Resting",
  "flags": 2,
  "mv": 1,
  "bt": 87,
  "ecg": 0.64,
  "lat": 0,
  "lon": 0,
  "gps": 0
}
```

For emergency packets, use:

```json
{"event":"fall_detected","mv":0}
{"event":"critical_fall","hr":58,"mv":0}
{"event":"no_movement","mv":0}
```

## Dataset links

- MIT-BIH Arrhythmia Database: https://physionet.org/content/mitdb/1.0.0/
- Sudden Cardiac Death Holter Database: https://physionet.org/content/sddb/1.0.0/
- Wearable Device Dataset: https://physionet.org/content/wearable-device-dataset/1.0.1/
- Wearable Exam Stress Dataset: https://physionet.org/content/wearable-exam-stress/1.0.0/
