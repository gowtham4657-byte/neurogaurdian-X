# NeuroGuardian X journal manuscript revision

## Main file
NeuroGuardian_X_IEEE_Journal_Revision.docx is the editable IEEE-style manuscript.
The matching .tex file uses IEEEtran and has not been compiled locally.
The qa directory contains internal Word-exported layout checks, not a separate submission.

## What changed
This revision adds a 5,400-case native sampling experiment, analytical reference,
explicit requirements, an evidence matrix, expanded literature, and a tighter
contribution statement. All original findings and their limitations are retained.

## Recorded evidence
- Production NeuroTwin: 1,600 synthetic evaluations.
- Randomized motion: 1,200 parameterized traces under 3 policies = 3,600 executions.
- Phase grid: 6 rates x 3 widths x 3 peaks x 100 phases = 5,400 native executions.
- Production controller: five local cases, including one observed timeout.
- Backend: four provider-outcome combinations and one failed-delivery webhook.

The phase grid is deterministic, not a clinical sample. All 3,144 captured grid
events are canceled by the original policy. No patient dataset was used, no
model was trained, and no alert was sent. The exploratory guard is not deployed.

## Reproduction
The source_snapshot folder contains selected files, not a complete app. Hashes
in source_manifest.json identify the evaluated implementation. On the original
machine this package is at <workspace>/output/<package> and the application at
<workspace>/neuroguardian_app.

1. Run simulation/run_motion_experiment.py with Python for original motion replay.
   The build uses the installed Windows MSVC vcvars64.bat path. Adapt that path
   or compile generated native_motion.cpp with an equivalent C++ compiler.
2. Run simulation/sampling_sweep.py for the additional phase grid. It re-extracts
   and compiles the production function; it does not contact any network.
3. From the Flutter app root set NGX_RESEARCH_RESULTS to the package results
   directory and run flutter test --no-pub with the absolute path to
   simulation/neurotwin_experiment_test.dart. Project dependencies must already
   be installed. The timing cases take 32 seconds and repeated latency will vary.
4. Run simulation/backend_contract_experiment.py with the existing backend Python
   environment containing FastAPI and HTTPX. Keep its credential-clearing,
   dotenv-disabling, provider-stubbing, and network-blocking safeguards intact.
5. Run revise_content.py, then build_revision.py with python-docx to regenerate
   the revised manuscript. Vector PDF and high-resolution PNG figures are included.
   build_original.py is provenance for the earlier draft, not the revised builder.

## Before journal submission
Fill author names, affiliation and corresponding email. Select the journal and
apply its current article template. All authors must independently review the
code, findings, references, interpretation, funding, conflicts, contributions,
and code/data licensing. Retain an accurate AI-assistance acknowledgment.
Deposit an approved licensed archive and add a stable access link.

This is a software-verification case study. Confirm that a synthetic-only case
study meets the selected journal's novelty and evidence requirements. Hardware
and external recordings remain necessary for medical or real-world accuracy
claims. No clinical validation, peer review, acceptance, or submission is claimed.
No production .env, credential, guardian number, or real location is distributed.

IEEE templates:
https://journals.ieeeauthorcenter.ieee.org/create-your-ieee-journal-article/authoring-tools-and-templates/
IEEE submission and AI disclosure policy:
https://journals.ieeeauthorcenter.ieee.org/become-an-ieee-journal-author/publishing-ethics/guidelines-and-policies/submission-and-peer-review-policies/
