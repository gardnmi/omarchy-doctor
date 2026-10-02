#!/usr/bin/env python3
"""Native Quickshell validation; opens a temporary panel, captures it, then exits."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--shell-root',default='/home/pi/Projects/video.on.desktop.omarchy/omarchy/shell')
parser.add_argument('--output',default=str(ROOT/'verification'))
args=parser.parse_args()
out=Path(args.output);out.mkdir(parents=True,exist_ok=True)
now=time.time()
rows=[]
for i,(key,domain,title) in enumerate([('cpu','cpu','Processor activity'),('memory','ram','Memory headroom'),('storage','disk','Root filesystem'),('gpu','gpu','Graphics & driver'),('services','system','System & user services'),('network','network','Route & DNS'),('battery','devices','Battery'),('shell','system','Omarchy shell'),('drives','disk','Physical drive health')]):
    rows.append(dict(id=key,domain=domain,title=title,state='warn' if key=='storage' else 'unknown' if key=='drives' else 'ok',summary='Root filesystem is 87% full.' if key=='storage' else 'This is fixture data for native validation. '+('A deliberately long diagnostic detail tests variable row height and scrolling. '*5 if i%3==0 else ''),evidence='Fixture output; not a real machine diagnosis.\n'+'Long evidence line. '*80,command='df -h /' if key=='storage' else 'uptime',metrics={},timestamp=now,duration_ms=125,change='new' if key=='storage' else 'baseline'))
samples=[dict(timestamp=now-177+i*3,metrics={'cpu_pct':25+(i%7)*5,'ram_available_gib':18+(i%4)/5,'ram_used_pct':60,'disk_used_pct':87,'gpu_pct':6+i%5}) for i in range(60)]
with tempfile.TemporaryDirectory(prefix='doctor-native-') as folder:
    work=Path(folder)
    for name in ('Commons','Ui','services'):(work/name).symlink_to(Path(args.shell_root)/name,target_is_directory=True)
    for src in [*ROOT.glob('*.qml'),ROOT/'Model.js',ROOT/'doctor.py']:shutil.copy2(src,work/src.name)
    qml='''import QtQuick
import Quickshell
import qs.Commons
ShellRoot {
    property int step: 0
    PanelWindow { implicitWidth:36;implicitHeight:35;anchors.top:true;anchors.left:true;visible:true
        Doctor { id:doctor;testMode:true;preferredWidth:1200 }
    }
    Timer { interval:350;running:true;repeat:true;onTriggered:{
        step++
        if(step===1){doctor.applyFixture(ROWS,SAMPLES);doctor.scans=[{id:"fixture",timestamp:Date.now()/1000,mode:"quick",state:"warn",rows:doctor.results}];doctor.open()}
        if(step===4)doctor.capture(OUT+"/native-overview.png")
        if(step===5)doctor.navigate("findings")
        if(step===7)doctor.capture(OUT+"/native-findings.png")
        if(step===8)doctor.moveFinding(7)
        if(step===9)console.log("NAV_GEOMETRY "+JSON.stringify(doctor.findingGeometry()))
        if(step===10)doctor.navigate("history")
        if(step===12)doctor.capture(OUT+"/native-history.png")
        if(step===13)doctor.navigate("settings")
        if(step===15)doctor.capture(OUT+"/native-settings.png")
        if(step===16){doctor.saveSetting("motion",false);doctor.preferredWidth=780;doctor.navigate("overview")}
        if(step===18)doctor.capture(OUT+"/native-compact.png")
        if(step===19){console.log("NATIVE_STATE "+doctor.status());doctor.preferredWidth=1200;Color.popups.background="#f2f4f2";Color.popups.text="#182224"}
        if(step===21)doctor.capture(OUT+"/native-light.png")
        if(step===22){doctor.applyFixture([{id:"permission",domain:"disk",title:"Drive health",state:"unknown",summary:"Permission denied",command:"",metrics:{}}],[]);console.log("UNKNOWN_STATE "+doctor.overallState)}
        if(step===23){
            doctor.results=[];doctor.historySamples=[];doctor.vitalsAt=0
            var t=Date.now()/1000
            doctor.ingest(JSON.stringify({schema:1,type:"vitals",timestamp:t,metrics:{cpu_pct:33}}),"watch")
            doctor.ingest(JSON.stringify({schema:1,type:"history",range_seconds:doctor.historySeconds,samples:[{timestamp:t-3,metrics:{cpu_pct:22}}],scans:[{timestamp:t,complete:false,rows:[{id:"cpu",state:"ok",title:"Partial CPU",domain:"cpu",summary:"Partial fixture",metrics:{}}]}]}),"history")
            console.log("HISTORY_MERGE "+JSON.stringify({count:doctor.historySamples.length,latest:doctor.historySamples[1].metrics.cpu_pct,complete:doctor.complete,state:doctor.overallState}))
            doctor.ingest(JSON.stringify({schema:1,type:"history",range_seconds:1,samples:[],scans:[]}),"history")
            console.log("STALE_HISTORY "+doctor.scans.length)
            doctor.close();console.log("CLOSED "+doctor.status());Qt.quit()
        }
    }}
}
'''.replace('ROWS',json.dumps(rows)).replace('SAMPLES',json.dumps(samples)).replace('OUT',json.dumps(str(out)))
    (work/'shell.qml').write_text(qml)
    p=subprocess.run(['qs','--no-color','--path',str(work/'shell.qml')],env={**os.environ,'QT_QPA_PLATFORM':'wayland'},capture_output=True,text=True,timeout=20)
    log=p.stdout+p.stderr;(out/'native-validation.log').write_text(log)
    assert p.returncode==0,log
    assert 'ERROR:' not in log and 'ReferenceError' not in log and 'TypeError' not in log and 'Unable to assign' not in log,log
    assert 'UNKNOWN_STATE unknown' in log,log
    history=json.loads(next(s.split('HISTORY_MERGE ',1)[1] for s in log.splitlines() if 'HISTORY_MERGE ' in s))
    assert history=={'count':2,'latest':33,'complete':False,'state':'unknown'},history
    assert 'STALE_HISTORY 1' in log,log
    line=next(s for s in log.splitlines() if 'NAV_GEOMETRY ' in s)
    geometry=json.loads(line.split('NAV_GEOMETRY ',1)[1])
    assert geometry['height']>0,geometry
    assert geometry['y']>=geometry['scroll']-1 and geometry['y']+geometry['height']<=geometry['scroll']+geometry['viewport']+1,geometry
    for page in ['overview','findings','history','settings','compact','light']:
        assert (out/f'native-{page}.png').stat().st_size>10000,page
    print('PASS: native pages rendered, unknown state preserved, variable-height keyboard selection visible, reduced motion, compact layout, close lifecycle.')
