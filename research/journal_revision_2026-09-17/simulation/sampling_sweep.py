"""Deterministic phase-grid evaluation of the extracted production function.

This uses analytical triangular impulses, not human recordings or a clinical
fall model. It never connects to a device, network or notification provider.
"""
from pathlib import Path
import csv
import json
import math
import subprocess
import time

from run_motion_experiment import prepare_native

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "results"
RATES = [1, 5, 10, 25, 50, 100]
WIDTHS = [0.08, 0.16, 0.24]
PEAKS = [2.8, 3.5, 4.2]
PHASES = 100
THRESHOLD = 2.6


def main():
    started = time.perf_counter()
    prepare_native()
    rows = []
    summary = []
    for hz in RATES:
        parameters = []
        input_file = OUT / "sampling_input.tmp"
        with input_file.open("w", encoding="ascii") as handle:
            for width in WIDTHS:
                for peak in PEAKS:
                    for phase_index in range(PHASES):
                        phase = (phase_index + 0.5) / PHASES
                        peak_time = 5 + phase / hz
                        oracle = False
                        trial = len(parameters)
                        for step in range(38 * hz + 1):
                            t = step / hz
                            g = 1 + (peak - 1) * max(0, 1 - 2 * abs(t - peak_time) / width)
                            oracle |= g > THRESHOLD
                            handle.write(f"{trial} {round(1000*t)} {g:.7f} 75 1\n")
                        above_width = width * (peak - THRESHOLD) / (peak - 1)
                        parameters.append(dict(trial=trial, hz=hz, width_s=width,
                            peak_g=peak, phase_index=phase_index, phase=phase,
                            above_threshold_s=above_width,
                            analytic_phase_probability=min(1, hz * above_width),
                            discrete_oracle_capture=int(oracle)))
        with input_file.open() as handle:
            result = subprocess.run([str(ROOT / "simulation/native_motion.exe")],
                stdin=handle, capture_output=True, text=True, check=True)
        input_file.unlink()
        current = []
        for line in result.stdout.splitlines():
            trial, captured, canceled, critical_ms = map(int, line.split(","))
            row = dict(parameters[trial], captured=captured,
                       canceled=canceled, critical_ms=critical_ms)
            current.append(row)
        assert len(current) == 900
        rows.extend(current)
        summary.append(dict(hz=hz, n=len(current),
            captured=sum(r["captured"] for r in current),
            canceled=sum(r["canceled"] for r in current),
            critical=sum(r["critical_ms"] >= 0 for r in current),
            oracle_mismatches=sum(r["captured"] != r["discrete_oracle_capture"] for r in current),
            observed_percent=100 * sum(r["captured"] for r in current)/len(current),
            analytic_percent=100 * sum(r["analytic_phase_probability"] for r in current)/len(current)))
        print(json.dumps(summary[-1]), flush=True)
    with (OUT / "sampling_sweep_trials.csv").open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    cell_errors = []
    for hz in RATES:
        for width in WIDTHS:
            for peak in PEAKS:
                cell = [r for r in rows if r["hz"] == hz and r["width_s"] == width and r["peak_g"] == peak]
                empirical = sum(r["captured"] for r in cell)/len(cell)
                cell_errors.append(abs(empirical-cell[0]["analytic_phase_probability"]))
    output = dict(design="deterministic midpoint phase grid; not a random population sample",
        duration_s=38, rates_hz=RATES, widths_s=WIDTHS, peaks_g=PEAKS,
        phase_points=PHASES, n=len(rows),
        max_cell_error_percentage_points=100*max(cell_errors),
        elapsed_host_s=time.perf_counter()-started, summary=summary)
    (OUT / "sampling_sweep_summary.json").write_text(json.dumps(output, indent=2))
    print("Completed", len(rows), "native phase-grid cases", flush=True)


if __name__ == "__main__":
    main()
