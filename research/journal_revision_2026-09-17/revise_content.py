"""Prepare the revised manuscript from the recorded study and new sweep."""
from pathlib import Path
import copy
import json
import re

ROOT = Path(__file__).resolve().parent
paper = json.loads((ROOT / "original_manuscript_content.json").read_text())
old = paper["blocks"]
sweep = json.loads((ROOT / "results/sampling_sweep_summary.json").read_text())
assert sweep["n"] == 5400
assert sum(x["oracle_mismatches"] for x in sweep["summary"]) == 0

paper["title"] = "Software Verification of Wearable Safety Monitoring in NeuroGuardian X"
paper["abstract"] = (
    "Wearable safety software must preserve suspected emergencies while distinguishing missing measurements and unconfirmed notifications from valid evidence. "
    "We present a reproducible software-in-the-loop study of NeuroGuardian X, an ESP32-S3 and Flutter prototype with a personalized statistical profile and notification backend. "
    "The evaluation executes production decision code on 1,600 synthetic physiological cases, 3,600 motion-policy replays, five controller cases, and five isolated backend cases. "
    "An additional 5,400-case phase-grid experiment checks impact capture against an analytical sampling model. "
    "For random short impacts followed by immobility, increasing the original policy from 1 to 50 Hz raises capture from 14/200 to 199/200, but neither rate produces a critical flag because the settling transient cancels the countdown. "
    "Across the phase grid, capture rises from 44/900 at 1 Hz to 888/900 at 100 Hz, while every captured event is canceled. "
    "An exploratory recovery guard preserves escalation in 199/200 immobile-impact cases but also escalates 198/200 unworn-device impacts. "
    "The physiological engine assigns Normal to all 200 missing-input cases and rejects every stationary baseline history. "
    "These results establish reproducible counterexamples and isolate sampling, state persistence, evidence availability, and notification semantics as distinct verification targets. "
    "The study evaluates software behavior; it provides no patient-level diagnostic accuracy or end-to-end emergency-delivery evidence."
)
paper["keywords"] = "Wearable monitoring, software verification, fall alert, signal quality, sampling, state machines, reproducibility."

replacements = {
1: "A wearable safety system transforms measurements into a sequence of decisions: accept a signal, recognize an event, retain or cancel an alert, and communicate its status. A defect at any transition can invalidate the intended behavior even when individual sensor values appear plausible. Verification must therefore address both numerical outputs and the meaning of the states presented to the wearer or guardian. This study asks whether an implemented wearable prototype satisfies observable monitoring and escalation requirements before clinical or field evaluation.",
3: "We make three bounded contributions. First, we define an executable evaluation spanning the firmware motion function, the production mobile decision engine, and isolated notification contracts, with source hashes and trial-level outputs. Second, we separate impact capture from event persistence through a sampling-only ablation and a controlled phase-grid experiment with an analytical reference. Third, we connect the resulting counterexamples to explicit requirements for missing-data handling, recovery cancellation, and alert-status reporting. The contribution is a traceable verification case study, not a new clinically validated detector or a claim that simulation alone establishes user safety.",
6: "SisFall provides recorded falls and activities of daily living acquired at 200 Hz [1]. Such recordings support activity-dependent evaluation, but a high-rate dataset does not by itself test how a particular implementation samples, retains, or cancels an event. Our generated impulses isolate these software mechanisms. They are not derived from SisFall, and the percentages reported here are not comparable with classification metrics measured on its recordings.",
7: "Hongn et al. describe wearable physiological recordings collected during acute stress and structured exercise [2]. These recordings address activity context and physiological measurement, whereas our stress and exercise scenarios vary scalar software inputs. The distinction matters: increased heart rate or electrodermal values can probe score behavior without supplying a clinical stress label. We do not estimate stress-detection accuracy.",
9: "The research questions are: RQ1, does the personal-profile engine distinguish missing or low-quality evidence from an ordinary supported result; RQ2, how do sampling rate and cancellation policy separately affect capture and escalation; and RQ3, which controller and notification states are actually supported by recorded evidence? All comparisons are internal to the evaluated prototype. We do not benchmark commercial watches or claim that the failure modes are unique to this device.",
39: "The poor-contact case retains shifted numeric values while lowering supplied quality and contact status, separating channel presence from channel trust. The missing case removes physiological measurements but preserves motion input. The ECG-scalar case is a feature perturbation, not an arrhythmia label. Each evaluation records component scores, the composite category, quality reliability, baseline eligibility, explanations, and input values. Means and sample standard deviations describe algorithm outputs; no generated scenario is treated as disease ground truth.",
50: "For each policy and trace, the harness records whether a fall/countdown flag appears, whether cancellation occurs, and the first critical-flag time. The randomized motion experiment contains 3,600 policy-trace evaluations, with 200 traces per family and policy. Capture is a threshold/state event; escalation is a later critical flag, not an outgoing message. Wilson 95% intervals summarize binomial proportions under the specified generator [11]. Policies share trace parameters, so their observations are paired rather than independent groups. No clinical power analysis or null-hypothesis significance claim is made. The deterministic phase-grid experiment below is reported separately without binomial confidence intervals.",
64: "The guarded candidate escalates 199/200 immobile-impact traces (99.5%; Wilson 95% interval 97.22-99.91%) and 0/200 recovery traces (upper Wilson bound 1.88%). It also escalates 198/200 unworn-device impacts (99.0%; interval 96.43-99.73%). Across the five seeds, immobile-impact escalation ranges from 39/40 to 40/40; recovery remains 0/40, and unworn-impact escalation ranges from 39/40 to 40/40. Thus, the behavior is not confined to one seed. The adverse unworn result prevents interpreting the retained countdown as reliable discrimination of a human emergency.",
66: "D. Controller and backend observations",
70: "The central finding is a separation between observing an input, retaining an event, and establishing an outcome. Sampling determines whether an impulse crosses the threshold in a sampled sequence. Cancellation logic determines whether that event survives until timeout. Channel validity determines whether a physiological score has interpretable evidence. Provider-return values determine whether an alert request was accepted, not whether a guardian received or acted on it. A single aggregate accuracy or success label would conflate these independently testable properties.",
71: "Motion acquisition should be separated from the connected BLE notification loop, with a bounded event record retained across communication interruptions. The guarded-policy ablation shows that windowed recovery evidence can preserve a countdown that the original difference rule cancels. Its false escalations also show why recovery hysteresis alone is insufficient. Contact and wearer-state evidence need their own measurement and validation path; neither a transient acceleration change nor prolonged stillness establishes that a person has recovered or become unconscious.",
74: "Physiological interpretation requires a defined measurement pathway. A periodic ADC-derived ECG scalar does not preserve rhythm morphology, the GSR scale is not calibrated conductance, and a supplied HRV value is not a quality-controlled beat-interval series. Before physiological conclusions are tested, the protocol must specify placement, reference equipment, acquisition rates, filtering, artifact handling, and inclusion criteria. The current NeuroTwin profile is best evaluated as an interpretable statistical software component with explicit assumptions.",
76: "Internal validity depends on faithful extraction, input generation, and interpretation of the recorded states. The native harness executes the original function and constants; hashes identify its provenance. Its Arduino clock and I/O are substituted, and its single-precision values can differ from Python analytical values near a threshold. The phase grid contains zero capture-oracle disagreements for the tested points, but does not prove equivalence for all inputs. The guarded policy was introduced during exploratory debugging, without held-out selection. Its parameters and input families must therefore remain fixed when a later confirmatory evaluation is designed.",
77: "Construct and external validity remain limited. Generated impulses contain no real fall biomechanics, pathology, skin-tone distribution, sensor saturation, or device-placement variation. The native tests bypass electronics and radio communication, mobile tests bypass BLE parsing and Android background restrictions, and backend tests bypass HTTP transport and actual providers. The scalar families cannot establish unconsciousness or disease. No battery life, GPS accuracy, message-delivery probability, ambulance response time, or end-to-end wristband reliability is measured. The single desktop controller duration is not an Android latency distribution.",
81: "This study combines implementation-level replay, an analytical sampling control, and requirement-based interpretation for a wearable safety prototype. In 5,400 deterministic phase-grid cases, capture agrees with the discrete oracle, yet every captured impulse is canceled before escalation; increasing acquisition rate alone therefore does not repair event persistence in these inputs. Randomized replays show that an exploratory guard retains most immobile-impact events while also escalating unworn-device impacts. Mobile and backend tests reveal additional evidence gaps in missing-input labels, stationary baseline eligibility, reason provenance, and delivery reporting. The contribution is a reproducible set of counterexamples and a method for separating numerical detection from state and communication correctness. Hardware measurements, external recordings, and prospective field evaluation are still required before claims about medical accuracy or operational safety.",
83: "The accompanying research package contains generators, the native extraction harness, the Flutter experiment, isolated backend tests, the phase-grid experiment, trial-level outputs, and editable manuscript and figure sources. SHA-256 hashes identify the implementation snapshot. The package contains no participant records, guardian contacts, production credentials, or live locations. It is available as accompanying material for author and reviewer inspection; no public repository DOI or independent artifact evaluation is claimed.",
87: "OpenAI Codex assisted in drafting and revising Sections I-VIII and the declarations, generating experiment and document code, and producing figures from executable results. Numerical findings are drawn from the accompanying recorded outputs; no patient observations were invented. The human authors are responsible for independently checking the implementation, measurements, references, interpretation, and final submitted manuscript.",
}

def p(text): return {"type":"p", "text":text}
def h(text): return {"type":"h2", "text":text}

inserts_before = {
7: [p("Bagala et al. evaluated 13 accelerometer-based algorithms on 29 real-world falls and reported substantial differences from results obtained with simulated falls [9]. Their study examines external performance; ours asks an earlier question about correctness under controlled inputs. The two forms of evidence are complementary. A software counterexample can expose an implementation problem without estimating its prevalence among real users.")],
9: [p("Metamorphic testing evaluates relations between executions when a complete output oracle is difficult to obtain [10]. This motivates controlled transformations such as replacing available measurements with missing ones, changing activity context, or increasing temporal resolution while retaining the policy. We use such comparisons to interpret behavior, alongside a direct numerical oracle for the phase-grid control. This is not a claim to introduce a new metamorphic-testing method or to provide a complete formal verification of the application.")],
35: [h("B. Evaluation requirements"),p("The test oracles are operational requirements rather than clinical diagnoses. R1 requires absent current physiology to remain distinguishable from an ordinary supported result. R2 requires otherwise eligible stationary rest to contribute to a resting profile. R3 requires a captured impact followed by continued immobility to retain the countdown until escalation. R4 requires explicit recovery or user cancellation to stop an active countdown. R5 requires an immediate-trigger reason to identify evidence actually present. R6 requires provider acceptance to remain distinct from delivery and acknowledgment. These requirements express the intended prototype behavior and the claims its interface can support; they are not a certification standard.")],
52: [h("G. Analytical sampling control"),
    p("A separate deterministic experiment removes the low-amplitude sinusoid from (4), producing one triangular impulse on a constant 1 g baseline. With threshold theta = 2.6 g, peak A > theta, and support width w, the time spent above threshold is d = w(A - theta)/(A - 1). If the sample phase is uniform over a period 1/f, the probability that at least one sample intersects this interval is:"),
    {"type":"eq", "text":"d = w(A - theta)/(A - 1)                         (5)", "latex":r"d=w\frac{A-\theta}{A-1}"},
    {"type":"eq", "text":"Pcapture(f) = min(1, f d)                       (6)", "latex":r"P_{\mathrm{capture}}(f)=\min(1,fd)"},
    p("Equation (6) follows because phases producing capture occupy length d within a sampling period when d < 1/f; otherwise every phase intersects the above-threshold interval. Equality at a threshold has zero probability under continuous phase. This is a sampling result for the constructed impulse, not a model of human falls. It predicts capture only, making no assumption that the implemented timer survives afterward."),
    p("We execute the extracted original function at f in {1, 5, 10, 25, 50, 100} Hz, w in {0.08, 0.16, 0.24} s, and A in {2.8, 3.5, 4.2} g. Each combination uses 100 midpoint phases, u_j = (j + 0.5)/100 for j = 0,...,99, with peak time 5 + u_j/f seconds. Each trace lasts 38 seconds and supplies constant heart rate 75 beats/min and connected status. The design yields 900 traces per rate and 5,400 native executions. The discrete oracle checks whether any sampled magnitude exceeds theta; the continuous-phase reference averages (6) across the nine peak/width combinations. The grid is a follow-up diagnostic extension, not a random sample, held-out evaluation, or external test set.")],
66: [h("C. Sampling control and persistence"),
    {"type":"table", "caption":"TABLE IV. DETERMINISTIC SAMPLING CONTROL", "head":["Rate Hz", "Capture / 900", "Model %", "Critical"], "widths":[0.58,1.05,0.92,0.93],
     "rows":[[str(x["hz"]),str(x["captured"]),f'{x["analytic_percent"]:.2f}',str(x["critical"])] for x in sweep["summary"]]},
    p("Table IV reports the phase-grid results. Capture increases from 44/900 (4.89%) at 1 Hz to 888/900 (98.67%) at 100 Hz. All 5,400 outputs agree with the discrete capture oracle. Across the 54 rate/width/peak cells, the maximum absolute difference between the 100-phase capture fraction and (6) is 0.889 percentage points, consistent with the finite grid. Every captured event is subsequently canceled, and no critical flag appears. Agreement at the capture stage therefore coexists with a persistence failure."),
    p("The grid and randomized families use different peak/width weightings and baseline signals. In particular, 832/900 captures at 50 Hz in the grid must not be pooled with 199/200 in the randomized immobile-impact family or interpreted as a replication discrepancy. Both experiments isolate the same distinction: increased temporal resolution can improve threshold observation while leaving the cancellation branch unchanged. The 100 Hz result is specific to the tested widths and amplitudes; it is not evidence that no higher rate or different waveform could change the state behavior.")],
69: [h("E. Requirement-level assessment"),
    {"type":"table", "caption":"TABLE V. REQUIREMENTS AND OBSERVED COUNTEREXAMPLES", "head":["Requirement", "Evidence", "Result"], "widths":[0.85,1.78,0.85], "rows":[
        ["R1 Availability", "200/200 missing cases Normal", "Violated"],
        ["R2 Rest profile", "0/200 stationary histories ready", "Violated"],
        ["R3 Persistence", "3144/3144 captured events canceled", "Violated"],
        ["R4 Cancellation", "Movement and reset cases cancel", "Observed"],
        ["R5 Provenance", "HR-drop reason without decline", "Violated"],
        ["R6 Alert status", "No retained delivery transition", "Incomplete"]]},
    p("Table V maps evidence to the declared requirements. Observed means that the specific local case satisfied the intended transition, not that all executions satisfy it. A finite test can establish a counterexample to a requirement but cannot establish universal safety. The matrix also distinguishes missing functionality, such as delivery-state persistence, from a numerical false classification.")],
72: [p("The unworn family exposes a separate observability limit. If a worn and an unworn device produce identical histories for all inputs consumed by a deterministic policy, that policy must return identical decisions. Relabeling the same observable sequence cannot supply wearer information. The 199 versus 198 critical counts arise from independently drawn parameters in two families with the same observable distribution, not from demonstrated wearer discrimination. Threshold tuning within this scalar representation cannot resolve this ambiguity; additional observables and an evaluated decision policy are needed.")],
76: [h("A. Internal validity")],
77: [h("B. Construct and external validity")],
78: [h("C. Validation beyond simulation")],
}

replacements.update({
4: "The measured system is software-in-the-loop. Electronics, battery life, skin contact, radio timing, Android background execution, internet transport, and guardian response are outside its scope. Scenario names describe constructed inputs; no participants, patient recordings, or live emergency messages were involved.",
8: "MIT-BIH contains 48 half-hour two-channel ECG records sampled at 360 Hz [3], [4], while this prototype transmits a periodic ECG scalar. Scalar-amplitude deviation cannot be equated with rhythm classification. Exam-stress [5], Sudden Cardiac Death Holter [6], and induced-stress/exercise [7] recordings are additional future resources, not study inputs. None of these records was used for fitting or testing; training-data use is zero.",
14: "Version 2 packets carry JSON fields for time, heart rate, oxygen saturation, HRV, GSR, temperature, ECG scalar, motion axes, quality, position, battery, and event flags. BLE requests a 517-byte maximum transmission unit; negotiation and delivery are not measured. Motion acquisition and buildMotionState execute inside notifyMetrics at a nominal one-second interval only while deviceConnected is true. State advancement is consequently tied to the connected notification loop, excluding scheduling jitter and missed intervals from the idealized replay.",
20: "Standard-deviation floors are 3 beats/min for heart rate, 0.8 percentage points for oxygen saturation, 5 ms for HRV, 4 arbitrary units for GSR, 0.2 degrees C for temperature, and 0.08 mV for ECG. Eligibility requires acceptable contact, quality at least 0.45, compatible activity, and usable physiology. It also rejects all samples with movementDetected false; the stationary-history experiment evaluates that condition.",
26: "Stress combines GSR, HRV, heart-rate and temperature deviations with recent transmitted stress values and activity context. The ECG component uses scalar amplitude, baseline deviation, and HRV load. Implemented trend windows span five minutes, thirty minutes, and one hour; the experimental histories do not validate those durations.",
28: "A fall signal starts the mobile 30-second countdown; a subsequent non-fall movement packet cancels it. Immediate escalation uses a heart-rate drop of at least 20 beats/min, compared with 22 in firmware, or Critical fall activity. Timing uses DateTime.now and periodic callbacks, so tests use real elapsed time rather than assuming the test framework virtualizes that clock.",
32: "Experiments ran on Windows on 17 September 2026 against app version 0.4.0+4, Flutter 3.19.5, and Dart 3.3.3. Backend versions were Python 3.10.10, FastAPI 0.141.1, and HTTPX 0.28.1; native compilation used Microsoft C++ version family 14.50. Production sources were not modified. SHA-256 hashes identify the evaluated working tree, including changes beyond its base Git commit.",
33: "The host harness extracts buildMotionState, MotionSample, and relevant constants verbatim. It substitutes a controllable millisecond clock, released SOS button, and inert outputs. The decision function runs as native C++ with single-precision motion values, not as ESP32 processor or radio emulation. Connected operation is assumed.",
34: "Flutter tests import the production Dart classes. Backend tests import endpoint functions with dotenv disabled, provider configuration removed, and notification/facility providers replaced by stubs. Network-client construction is blocked to prevent synthetic alerts reaching real contacts.",
36: "Seeds 17, 29, 43, 71, and 101 each generate 40 repetitions per scenario: 200 cases per scenario and 1,600 evaluations. Each case has 120 preceding one-second observations and one current observation, excluded from its baseline. Histories use ordinary resting inputs with movementDetected true except in the stationary scenario, permitting comparison with otherwise eligible quiet-rest histories.",
38: "Ordinary continuous ranges are temperature 36.5-36.8 degrees C, ECG 0.55-0.69 mV, transmitted stress 25-35, and quality 0.85-0.95. Integer endpoints are inclusive; continuous upper endpoints are excluded. GSR is an arbitrary 0-100 scalar, and HRV is supplied rather than waveform-derived. These are engineering inputs, not clinical reference intervals.",
48: "Guard parameters were engineering choices made during debugging, without patient training or held-out selection. Original-policy replay at 50 Hz isolates sampling from cancellation changes. Python and C++ policies are compared by state transitions, not execution speed.",
51: "Five controller cases cover fall-then-silence, movement after five seconds, manual reset, stillness without fall, and Critical fall activity. No-response cases run concurrently for 32 seconds; the timeout is one observation, not a latency distribution. Backend cases enumerate all four provider outcomes and one failed-delivery webhook. No physical disconnection, Android suspension, or live provider is tested.",
78: "Validation should proceed from regression tests for these counterexamples, stale packets and timestamp order to instrumented bench measurements of acquisition, contact, packet handling, and power. Ethically reviewed participant studies should compare sensors with appropriate references and assess ordinary activity before controlled fall-related testing. Prospective field evaluation requires consent, monitoring responsibility, stopping rules, and independent event adjudication.",
79: "Future modeling requires participant-level partitions, with normalization and feature selection fitted only on training data. Waveform acquisition must precede an ECG benchmark; channel harmonization must precede wearable stress analysis. Datasets representing different tasks and populations should not be pooled into an unspecified disease label. Calibrated probabilities and condition-specific conclusions require external validation.",
})

# Preserve the existing figure sequence and renumber method subsections after R1-R6.
method_titles={35:"C. NeuroTwin synthetic cases",40:"D. Motion generator and sampling comparison",
               46:"E. Experimental guarded recovery policy",49:"F. Endpoints and controller contracts"}
out=[]
for i,b in enumerate(old):
    out.extend(copy.deepcopy(inserts_before.get(i,[])))
    b=copy.deepcopy(b)
    if i in replacements: b["text"]=replacements[i]
    if i in method_titles: b["text"]=method_titles[i]
    out.append(b)

extra_refs = [
    (9, 'F. Bagala et al., "Evaluation of accelerometer-based fall detection algorithms on real-world falls," PLoS ONE, vol. 7, no. 5, Art. no. e37062, 2012, doi: 10.1371/journal.pone.0037062.', 'https://doi.org/10.1371/journal.pone.0037062'),
    (10, 'T. Y. Chen, F.-C. Kuo, H. Liu, P.-L. Poon, D. Towey, T. H. Tse, and Z. Q. Zhou, "Metamorphic testing: A review of challenges and opportunities," ACM Computing Surveys, vol. 51, no. 1, Art. no. 4, 2018, doi: 10.1145/3143561.', 'https://doi.org/10.1145/3143561'),
    (11, 'NIST/SEMATECH, "Confidence intervals," e-Handbook of Statistical Methods, sec. 7.2.4.1. Accessed: Sep. 17, 2026. [Online]. Available: https://www.itl.nist.gov/div898/handbook/prc/section2/prc241.htm', 'https://www.itl.nist.gov/div898/handbook/prc/section2/prc241.htm')
]
out.extend({"type":"ref","text":f"[{n}] {s}","url":url} for n,s,url in extra_refs)
ref_map={int(re.match(r"\[(\d+)\]",b["text"])[1]):b for b in out if b["type"]=="ref"}
order=[]
for b in out:
    if b["type"]!="ref":
        for x in re.findall(r"\[(\d+)\]",b.get("text","")):
            if int(x) not in order: order.append(int(x))
assert set(order)==set(ref_map)
numbers={old_id:new_id for new_id,old_id in enumerate(order,1)}
body=[b for b in out if b["type"]!="ref"]
for b in body:
    if "text" in b:
        b["text"]=re.sub(r"\[(\d+)\]",lambda m:f'[{numbers[int(m[1])]}]',b["text"])
for old_id in order:
    b=ref_map[old_id]
    b["text"]=re.sub(r"^\[\d+\]",f"[{numbers[old_id]}]",b["text"])
    body.append(b)
paper["blocks"]=body
(ROOT/"manuscript_content.json").write_text(json.dumps(paper,indent=2))
print(json.dumps({"title":paper["title"], "abstract_words":len(paper["abstract"].split()),
    "words":len((paper["abstract"]+' '+' '.join(b.get('text','') for b in body)).split()),
    "tables":sum(b['type']=='table' for b in body), "references":len(order)}))
