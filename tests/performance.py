#!/usr/bin/env python3
"""Measure this plugin's isolated render cost and verify animation gating."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

ROOT=Path(__file__).resolve().parents[1]
SHELL=Path('/home/pi/Projects/video.on.desktop.omarchy/omarchy/shell')
with tempfile.TemporaryDirectory(prefix='doctor-perf-') as folder:
    work=Path(folder)
    for name in ('Commons','Ui','services'):(work/name).symlink_to(SHELL/name,target_is_directory=True)
    for src in [*ROOT.glob('*.qml'),ROOT/'Model.js',ROOT/'doctor.py']:shutil.copy2(src,work/src.name)
    (work/'shell.qml').write_text('''import QtQuick
import Quickshell
ShellRoot {
    PanelWindow { implicitWidth:36;implicitHeight:35;anchors.top:true;anchors.left:true;visible:true
        Doctor { id:doctor;testMode:true;preferredWidth:1200 }
    }
    Timer{interval:200;running:true;onTriggered:{doctor.applyFixture([{id:"cpu",domain:"cpu",title:"CPU",state:"ok",summary:"Performance fixture",metrics:{},command:""}],[{timestamp:Date.now()/1000,metrics:{cpu_pct:35,ram_available_gib:12,ram_used_pct:45,disk_used_pct:60,gpu_pct:20}}]);doctor.open()}}
    Timer{interval:2000;running:true;onTriggered:console.log("PHASE_A "+JSON.stringify(doctor.animationSnapshot()))}
    Timer{interval:8000;running:true;onTriggered:console.log("PHASE_B "+JSON.stringify(doctor.animationSnapshot()))}
    Timer{interval:9000;running:true;onTriggered:doctor.saveSetting("motion",false)}
    Timer{interval:10000;running:true;onTriggered:console.log("REDUCED_A "+JSON.stringify(doctor.animationSnapshot()))}
    Timer{interval:16000;running:true;onTriggered:console.log("REDUCED_B "+JSON.stringify(doctor.animationSnapshot()))}
    Timer{interval:17000;running:true;onTriggered:{doctor.saveSetting("motion",true);doctor.close()}}
    Timer{interval:18000;running:true;onTriggered:console.log("CLOSED_A "+JSON.stringify(doctor.animationSnapshot()))}
    Timer{interval:24000;running:true;onTriggered:console.log("CLOSED_B "+JSON.stringify(doctor.animationSnapshot()))}
    Timer{interval:25000;running:true;onTriggered:Qt.quit()}
}
''')
    log_path=ROOT/'verification/performance.log'
    with log_path.open('w') as log:
        process=subprocess.Popen(['qs','--no-color','--path',str(work/'shell.qml')],env={**os.environ,'QT_QPA_PLATFORM':'wayland'},stdout=log,stderr=log)
        start=time.monotonic();readings={}
        try:
            for moment in [2,8,10,16,18,24]:
                time.sleep(max(0,start+moment-time.monotonic()))
                stat=Path(f'/proc/{process.pid}/stat').read_text();values=stat[stat.rfind(')')+2:].split()
                readings[moment]=(int(values[11])+int(values[12]))/os.sysconf('SC_CLK_TCK')
            process.wait(timeout=5)
        finally:
            if process.poll() is None:process.terminate();process.wait(timeout=3)
    text=log_path.read_text()
    def event(name):return json.loads(next(s.split(name+' ',1)[1] for s in text.splitlines() if name+' ' in s))
    assert event('PHASE_A') and event('PHASE_A')!=event('PHASE_B'),text
    assert event('REDUCED_A')==event('REDUCED_B'),text
    assert event('CLOSED_A')==event('CLOSED_B'),text
    results={name:round((readings[b]-readings[a])/(b-a)*100,2) for name,a,b in [('animated_cpu_percent_of_one_core',2,8),('reduced_cpu_percent_of_one_core',10,16),('closed_cpu_percent_of_one_core',18,24)]}
    results['animation_gates']='PASS: motion advances while open; phases stop in reduced mode and when closed.'
    (ROOT/'verification/performance.json').write_text(json.dumps(results,indent=2)+'\n')
    print(json.dumps(results,indent=2))
