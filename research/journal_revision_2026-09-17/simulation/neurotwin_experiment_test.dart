import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:neuroguardian_app/features/metrics/metrics.dart';
import 'package:neuroguardian_app/features/neurotwin/neurotwin_engine.dart';
import 'package:neuroguardian_app/features/emergency/auto_sos_provider.dart';

final resultsDir = Directory(Platform.environment['NGX_RESEARCH_RESULTS']!);
final anchor = DateTime.utc(2026, 9, 17, 12);

Metrics sample(Random r, int second, String scenario) {
  var hr = 72 + r.nextInt(9)-4;
  int? spo2 = 97+r.nextInt(3);
  double? hrv = 45+r.nextDouble()*10;
  double? gsr = 28+r.nextDouble()*8;
  double? ecg = .55+r.nextDouble()*.14;
  var temp = 36.5+r.nextDouble()*.3;
  var stress = 25+r.nextDouble()*10;
  var activity = 'Resting';
  var movement = true;
  var fall = false;
  var quality = .85+r.nextDouble()*.1;
  var fit = true;
  if(scenario=='stationary') movement=false;
  if(scenario=='stress_shift') {
    hr=95+r.nextInt(21); hrv=15+r.nextDouble()*10;
    gsr=75+r.nextDouble()*15; stress=75+r.nextDouble()*15;
  }
  if(scenario=='exercise') {
    hr=120+r.nextInt(26);hrv=20+r.nextDouble()*15;
    gsr=50+r.nextDouble()*15;stress=45+r.nextDouble()*15;activity='Running';
  }
  if(scenario=='ecg_scalar_shift') ecg=1.6+r.nextDouble()*.4;
  if(scenario=='poor_contact') {
    quality=.05+r.nextDouble()*.15;fit=false;
    hr=140+r.nextInt(41);spo2=80+r.nextInt(10);hrv=8+r.nextDouble()*7;
    gsr=85+r.nextDouble()*10;ecg=1.8+r.nextDouble()*.2;stress=85;temp=39;
  }
  if(scenario=='missing') {
    hr=0;spo2=null;hrv=null;gsr=null;ecg=null;temp=0;stress=0;quality=0;fit=false;
  }
  if(scenario=='fall_inactive') {fall=true;movement=false;activity='Fall detected';}
  return Metrics(timestamp:anchor.add(Duration(seconds:second)),heartRate:hr,spo2:spo2,
    hrv:hrv,gsrLevel:gsr,ecgMv:ecg,temperatureC:temp,stressLevel:stress,
    activity:activity,movementDetected:movement,fallDetected:fall,packetVersion:2,
    ppgQuality:quality,ecgQuality:quality,gsrQuality:quality,temperatureQuality:quality,
    watchFit:fit,skinContact:fit,accelXG:0,accelYG:0,accelZG:1,
    gyroXDps:0,gyroYDps:0,gyroZDps:0);
}

void main() {
  test('reproducible synthetic NeuroTwin scenarios using production engine', () {
    final rows=<Map<String,dynamic>>[];
    for(final seed in [17,29,43,71,101]) {
      for(final scenario in ['normal','stationary','stress_shift','exercise',
        'ecg_scalar_shift','poor_contact','missing','fall_inactive']) {
        for(var repeat=0;repeat<40;repeat++) {
          final r=Random(seed*100000+repeat);
          final history=[for(var t=-120;t<0;t++)sample(r,t,
            scenario=='stationary'?'stationary':'normal')];
          // The first changed packet is evaluated against preceding, separate history.
          final latest=sample(r,0,scenario);
          final s=const NeuroTwinEngine().build(latest:latest,history:history)!;
          expect(s.riskScore.isFinite && s.riskScore>=0 && s.riskScore<=100,isTrue);
          rows.add({'seed':seed,'repeat':repeat,'scenario':scenario,
            'heart_rate':latest.heartRate,'hrv':latest.hrv,'gsr':latest.gsrLevel,
            'ecg_mv':latest.ecgMv,'spo2':latest.spo2,'temperature':latest.temperatureC,
            'quality':s.quality.overall,'quality_reliable':s.quality.reliableForRisk,
            'baseline_n':s.baseline.validSampleCount,'baseline_ready':s.baseline.ready,
            'risk_score':s.riskScore,'risk_category':s.category.name,
            'stress_score':s.algorithm.stressScore,'ecg_score':s.algorithm.ecgAnomalyProbability,
            'fall_score':s.algorithm.fallProbability,'reasons':s.riskReasons,
            'deviations':s.detectedDeviations});
        }
      }
    }
    resultsDir.createSync(recursive:true);
    File('${resultsDir.path}/neurotwin_trials.json').writeAsStringSync(jsonEncode(rows));
    expect(rows.length,1600);
  });

  test('controller fault injection with real elapsed time and no network', () async {
    final rows=<Map<String,dynamic>>[];
    Metrics m(String s)=>sample(Random(17),0,s);
    final cases=['fall_then_silence_32s','fall_then_movement_5s','manual_reset',
      'stationary_without_fall_32s','critical_fall_flag'];
    final cs=[for(final _ in cases)AutoSosController()];
    final start=DateTime.now();
    double? triggerElapsed;
    final remove=cs[0].addListener((s) {
      if(s.isTriggered) triggerElapsed=DateTime.now().difference(start).inMilliseconds/1000;
    });
    for(var i=0;i<3;i++)cs[i].handleMetrics(m('fall_inactive'));
    cs[3].handleMetrics(m('stationary'));
    cs[4].handleMetrics(Metrics(timestamp:anchor,heartRate:75,stressLevel:20,
        temperatureC:36.7,activity:'Critical fall',fallDetected:true,movementDetected:false));
    rows.add({'case':cases[4],'status':cs[4].state.status.name,'reason':cs[4].state.triggerReason.name});
    await Future<void>.delayed(const Duration(seconds:5));
    cs[1].handleMetrics(m('normal')); cs[2].reset();
    for(final i in [1,2])rows.add({'case':cases[i],'status':cs[i].state.status.name,'reason':cs[i].state.triggerReason.name});
    await Future<void>.delayed(const Duration(seconds:27));
    for(final i in [0,3])rows.add({'case':cases[i],'status':cs[i].state.status.name,
      'reason':cs[i].state.triggerReason.name,'observed_elapsed_s':i==0?triggerElapsed:null});
    expect(cs[0].state.status,AutoSosStatus.triggered);
    expect(cs[3].state.status,AutoSosStatus.idle);
    remove(); for(final c in cs)c.dispose();
    resultsDir.createSync(recursive:true);
    File('${resultsDir.path}/controller_cases.json').writeAsStringSync(jsonEncode(rows));
    expect(rows.length,5);
  },timeout:const Timeout(Duration(seconds:60)));
}
