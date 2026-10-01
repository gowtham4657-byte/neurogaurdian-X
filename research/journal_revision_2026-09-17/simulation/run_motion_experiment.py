"""Synthetic software experiments; no devices, patient records or notifications."""
from pathlib import Path
import csv
import hashlib
import json
import math
import random
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT.parents[1] / 'neuroguardian_app'
OUT = ROOT / 'results'
OUT.mkdir(parents=True, exist_ok=True)
SEEDS = [17, 29, 43, 71, 101]
GROUPS = ['quiet', 'walking', 'impact_immobile', 'impact_recovery',
          'impact_hr_drop', 'unworn_impact']


def extract_block(text, signature):
    start = text.index(signature)
    brace = text.index('{', start)
    depth = 1
    end = brace + 1
    while depth:
        depth += (text[end] == '{') - (text[end] == '}')
        end += 1
    return text[start:end]


def prepare_native():
    source_path = APP / 'firmware/esp32_neuroguardian_ble/esp32_neuroguardian_ble.ino'
    src = source_path.read_text(encoding='utf-8')
    function = extract_block(src, 'void buildMotionState(')
    struct = extract_block(src, 'struct MotionSample') + ';'
    names = ['FALL_COUNTDOWN_MS', 'IMPACT_THRESHOLD_G', 'MOVEMENT_DELTA_G',
             'RUNNING_DELTA_G', 'SUDDEN_HR_DROP_BPM', 'SOS_BUTTON_PIN',
             'ACTIVITY_RESTING', 'ACTIVITY_WALKING', 'ACTIVITY_RUNNING',
             'ACTIVITY_FALL', 'ACTIVITY_NO_MOVEMENT', 'FLAG_FALL',
             'FLAG_MOVEMENT', 'FLAG_SOS_COUNTDOWN', 'FLAG_CRITICAL', 'FLAG_MANUAL_SOS']
    constants = '\n'.join(re.search(r'static const [^;]+\b' + name + r'\s*=[^;]+;', src)[0]
                          for name in names)
    harness = '''#include <cstdint>
#include <cmath>
#include <cstdio>
unsigned long clock_ms = 0;
unsigned long millis() { return clock_ms; }
const int LOW = 0;
int digitalRead(int) { return 1; }
void refreshAlertOutput() {}
unsigned long fallStartedMs=0, commandPulseUntilMs=0;
bool fallCountdownActive=false, criticalNow=false, appAlertActive=false;
float lastAccelG=1.0f;
uint8_t previousHeartRate=0;
'''
    harness += constants + '\n' + struct + '\n' + function + '\n'
    harness += '''int main() {
  int id=-1, next, hr, connected;
  unsigned long ms;
  float g;
  int captured=0, canceled=0;
  long critical=-1;
  auto finish=[&]() { if(id>=0) printf("%d,%d,%d,%ld\\n",id,captured,canceled,critical); };
  while(scanf("%d %lu %f %d %d",&next,&ms,&g,&hr,&connected)==5) {
    if(next!=id) { finish(); id=next; captured=canceled=0; critical=-1;
      fallStartedMs=0; fallCountdownActive=criticalNow=appAlertActive=false;
      previousHeartRate=0; lastAccelG=1.0f; commandPulseUntilMs=0; }
    clock_ms=ms;
    if(!connected) continue;
    const bool before=fallCountdownActive;
    MotionSample m={0,0,g,0,0,0,g,std::fabs(g-lastAccelG),true};
    uint8_t activity=0, flags=0;
    buildMotionState((uint8_t)hr,m,activity,flags);
    if(flags & FLAG_FALL) captured=1;
    if(before && !fallCountdownActive) canceled=1;
    if((flags & FLAG_CRITICAL) && critical<0) critical=(long)ms;
  }
  finish();
}
'''
    (ROOT / 'simulation/native_motion.cpp').write_text(harness, encoding='ascii')
    (OUT / 'firmware_extraction.json').write_text(json.dumps({
        'source': str(source_path.relative_to(APP)),
        'source_sha256': hashlib.sha256(source_path.read_bytes()).hexdigest(),
        'function_sha256': hashlib.sha256(function.encode()).hexdigest(),
        'extraction': 'verbatim function body and constants; Arduino I/O and clock stubbed',
        'not_emulated': ['BLE stack', 'sensor electronics', 'ESP32 scheduling', 'radio reconnection'],
    }, indent=2), encoding='utf-8')
    build = ROOT / 'simulation/build_native.cmd'
    build.write_text('@echo off\ncall "C:\\Program Files\\Microsoft Visual Studio\\18\\Insiders\\VC\\Auxiliary\\Build\\vcvars64.bat" >nul\n'
                     'cl /nologo /EHsc /O2 native_motion.cpp /Fe:native_motion.exe\n', encoding='ascii')
    run = subprocess.run(['cmd.exe', '/d', '/c', str(build)], cwd=build.parent,
                         capture_output=True, text=True)
    (OUT / 'native_compile.log').write_text(run.stdout + run.stderr)
    if run.returncode:
        raise RuntimeError(run.stdout + run.stderr)


def trace(params, hz):
    group = params['group']
    t0, width, peak, phase = (params[k] for k in ['impact_time', 'width', 'peak', 'phase'])
    for i in range(45 * hz + 1):
        t = i / hz
        g = 1 + 0.004 * math.sin(2 * math.pi * 0.7 * t + phase)
        if group == 'walking':
            g += 0.35 * math.sin(2 * math.pi * 1.8 * t + phase)
        if group not in ['quiet', 'walking']:
            u = abs(t - t0) / (width / 2)
            g += max(0, 1 - u) * (peak - 1)
        if group == 'impact_recovery' and t >= t0 + 8:
            g += 0.35 * math.sin(2 * math.pi * 1.8 * (t - t0 - 8))
        hr = 45 if group == 'impact_hr_drop' and t >= t0 - width / 2 else 75
        yield round(t * 1000), g, hr


def guarded_candidate(samples):
    # An explicitly experimental alternative; never written to the production firmware.
    start = None
    recovery = None
    first_critical = -1
    captured = canceled = 0
    previous_hr = 0
    window = []
    for ms, g, hr in samples:
        window.append((ms, g))
        window = [(t, a) for t, a in window if ms - t <= 500]
        if start is None and g > 2.6:
            start = ms
            captured = 1
        if start is not None:
            if previous_hr > 0 and previous_hr - hr >= 22 and first_critical < 0:
                first_critical = ms
            if ms - start > 1500:
                moving = max(a for _, a in window) - min(a for _, a in window) > 0.18
                if moving:
                    recovery = ms if recovery is None else recovery
                else:
                    recovery = None
                if recovery is not None and ms - recovery >= 2000:
                    start = recovery = None
                    canceled = 1
            if start is not None and ms - start >= 30000 and first_critical < 0:
                first_critical = ms
        previous_hr = hr
    return captured, canceled, first_critical


def wilson(k, n):
    z = 1.959963984540054
    p = k / n
    c = (p + z*z/(2*n)) / (1+z*z/n)
    h = z * math.sqrt(p*(1-p)/n+z*z/(4*n*n)) / (1+z*z/n)
    return [100*(c-h), 100*(c+h)]


def main():
    prepare_native()
    params = []
    for seed in SEEDS:
        rng = random.Random(seed)
        for group in GROUPS:
            for repeat in range(40):
                params.append(dict(trial=len(params), seed=seed, repeat=repeat, group=group,
                    impact_time=5+rng.random(), width=rng.uniform(.08,.24),
                    peak=rng.uniform(2.8,4.2), phase=rng.uniform(0,2*math.pi)))
    with (OUT / 'motion_parameters.csv').open('w', newline='') as f:
        w=csv.DictWriter(f, fieldnames=list(params[0])); w.writeheader(); w.writerows(params)
    all_results=[]
    for hz in [1,50]:
        inp=OUT / 'motion_input.tmp'
        with inp.open('w') as f:
            for p in params:
                for ms,g,hr in trace(p,hz):
                    f.write(f"{p['trial']} {ms} {g:.7f} {hr} 1\n")
        with inp.open() as f:
            proc=subprocess.run([str(ROOT/'simulation/native_motion.exe')], stdin=f,
                                capture_output=True, text=True, check=True)
        for line in proc.stdout.splitlines():
            tid,cap,can,critical=map(int,line.split(','))
            p=params[tid]
            all_results.append({**p, 'policy':f'original_{hz}Hz', 'captured':cap,
                                'canceled':can,'critical_ms':critical})
        inp.unlink()
    for p in params:
        cap,can,critical=guarded_candidate(trace(p,50))
        all_results.append({**p,'policy':'guarded_50Hz','captured':cap,
                            'canceled':can,'critical_ms':critical})
    with (OUT/'motion_trials.csv').open('w',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(all_results[0]));w.writeheader();w.writerows(all_results)
    summary=[]
    for policy in ['original_1Hz','original_50Hz','guarded_50Hz']:
        for group in GROUPS:
            rows=[r for r in all_results if r['policy']==policy and r['group']==group]
            cap=sum(r['captured'] for r in rows)
            crit=sum(r['critical_ms']>=0 for r in rows)
            times=[r['critical_ms']/1000-r['impact_time'] for r in rows if r['critical_ms']>=0]
            summary.append(dict(policy=policy,group=group,n=len(rows),captured=cap,
                                critical=crit,critical_percent=100*crit/len(rows),
                                critical_wilson95=wilson(crit,len(rows)),
                                mean_time_from_peak_s=sum(times)/len(times) if times else None))
    (OUT/'motion_summary.json').write_text(json.dumps(summary,indent=2))
    print(json.dumps(summary,indent=2))


if __name__=='__main__':
    main()
