# Research archive handover

This directory preserves the 17 September 2026 journal draft, generators, source
snapshots and recorded synthetic results. Its copied scientific content has not
been revised for this upload. Outputs are historical evidence, not newly rerun
experiments. The manuscript is not peer reviewed or accepted by IEEE.

## Important reproduction limitations

The original scripts assume the former workspace directory layout, a neighbouring
`neuroguardian_app` folder and a machine-specific Microsoft C++ compiler path.
Their original README documents that environment. They will not run unchanged
from this new archive location. Do not mistake a path failure for a new result.

Before rerunning:

1. Work in a separate copy so original recorded outputs remain unchanged.
2. Point `APP` in the Python harnesses at the archived `source_snapshot` for
   firmware/backend replay rather than the latest application checkout.
3. Configure the local compiler in `prepare_native`; preserve the extraction logic.
4. For Dart tests, use a separate full Flutter checkout with the archived source
   files and lockfile, verifying hashes against `source_manifest.json`.
5. Retain provider stubs, disabled dotenv loading and network blocking. Never
   supply live credentials or contacts to the simulation.
6. Record new toolchain versions and store rerun outputs separately.

The snapshot is selected source files, not a complete standalone Flutter project.
Making a portable, fully pinned reproduction package is still pending.

## Pre-submission findings

- Confirm author details, funding, conflicts and the selected journal's requirements.
- Expand directly relevant verification literature and justify the contribution.
- Table I omits exercise GSR (50-65) and transmitted stress (45-60) perturbations.
- Specify that 3,144 canceled captures refer to the deterministic phase grid.
- Obtain a proper similarity review; no certified plagiarism percentage is available.
- Retain the AI-assistance acknowledgment and all synthetic-only limitations.

All archived results are software tests. They do not establish clinical accuracy,
hardware reliability or real guardian/hospital message delivery. The guarded policy
is exploratory research, not the current firmware and not a validated safety fix.
