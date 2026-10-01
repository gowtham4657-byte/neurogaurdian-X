# Current implementation and handover

Updated 1 October 2026. This is a development prototype, not a certified medical
device or an operational ambulance-dispatch service. Older reports and hardware
drawings in this repository describe earlier designs; this status takes precedence
when assessing implementation completeness.

## Architecture

ESP32-S3 sensor acquisition -> BLE packets -> Flutter Metrics parser -> local
history and NeuroTwin -> mobile emergency controller -> Python FastAPI backend
-> configured guardian notification providers.

The backend may enrich an alert with Google Places medical facilities. Finding a
facility does not mean that hospital or an ambulance receives or accepts a request.
An accepted backend request is not evidence of delivery or human acknowledgment.

## Latest source included

- `lib/features/neurotwin/`: statistical baseline, quality heuristics, trends,
  composite scores, explanations, providers and NeuroTwin screen.
- `lib/features/metrics/`: expanded sensor model and rule-based processing.
- `lib/features/ble/ble_repository.dart`: packet parsing and BLE connection logic.
- `lib/features/history/history_repository.dart`: stored sensor fields.
- `firmware/esp32_neuroguardian_ble/`: packet-v2 firmware and hardware notes.
- `test/`: BLE packet, controller, stress, NeuroTwin and widget tests.
- `backend/`: server-side facility lookup, WhatsApp/push integration and webhook
  routes. Provider credentials are supplied privately, not stored in this repo.

## Inputs and outputs

Inputs include available heart rate, SpO2, HRV, GSR, temperature, ECG scalar,
accelerometer/gyroscope data, quality/contact flags, GPS, battery and event flags.
Presence in the packet model does not mean a sensor is connected or calibrated.
Pressure/altitude remain placeholders in the inspected configuration.

Outputs include displayed measurements, history, quality indicators, personal
baseline deviations, rule scores and reasons, and suspected-fall alert states.
The system does not establish unconsciousness, cardiac arrest, or a diagnosis.
No machine-learning model was trained for the archived research study.

## Hardware limitations

Firmware currently uses generic ESP32-S3 DevKit GPIO assignments. Do not assume
these are valid for the XIAO ESP32-S3 or copy older wiring diagrams without checking
the exact board, voltage levels and modules. MAX30102 and TinyGPSPlus paths are
disabled by default. Dedicated calibrated body-temperature acquisition is unfinished.
An ECG amplitude scalar is not a diagnostic ECG waveform. Optical/internal sensor
temperature must not be presented as validated body temperature.

## Known safety issues from the archived software study

The 17 September study evaluates a specific implementation snapshot, not people.
It reports missing physiology labeled Normal, stationary baseline histories
excluded, impact settling motion canceling countdowns, and a critical-fall reason
incorrectly attributed to heart-rate decline. Provider acceptance is not persisted
as a verified delivery history. These findings remain release blockers unless
fixed and demonstrated by new regression and integration evidence.

The experimental guarded-recovery policy is research code only; it is not deployed
in firmware. It also escalates unworn-device impacts and is not a validated fix.
The intended 30-second no-movement flow must not be advertised as proven reliable.

## Verification for this upload

On 1 October 2026, before archiving the research package:

- `flutter test --no-pub`: 14 tests passed.
- `flutter analyze --no-pub`: no issues found.
- These checks do not prove real sensor accuracy, BLE/background reliability,
  notification delivery, electrical safety or clinical effectiveness.
- Firmware has not been compiled or flashed as part of this repository upload.
- No live SOS or provider notification was sent for this upload.

## Work required before release

1. Resolve the known controller, baseline and missing-data counterexamples.
2. Validate exact wiring, power, skin contact, calibration and acquisition timing.
3. Test packet loss, stale data, reconnects, locked-phone/background behaviour,
   permissions, offline queues, retries and battery drain on real devices.
4. Add authenticated user/device provisioning, consent, access control, retention
   limits and verified delivery/guardian acknowledgment states.
5. Verify notification-provider configuration and permissions in controlled tests;
   do not send test emergencies to hospitals or emergency services.
6. Establish any real dispatch partnership separately. Obtain appropriate ethics,
   privacy and regulatory advice before participant studies or public deployment.

## Research and manuscript

`research/journal_revision_2026-09-17/` is an archived, synthetic-only study with
source snapshots and recorded outputs. See its repository handover notes before
running scripts. The editable manuscript is a draft with author placeholders,
not an accepted IEEE article. The pre-submission review identified reproducibility,
novelty, scenario-description and journal-template work still required. No certified
plagiarism or clinical validation report exists.
