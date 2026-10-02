#!/usr/bin/env python3
"""Verify a native collector that exits 7 after one healthy row stays incomplete."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
ROOT=Path(__file__).resolve().parents[1]
SHELL=Path('/home/pi/Projects/video.on.desktop.omarchy/omarchy/shell')
with tempfile.TemporaryDirectory(prefix='doctor-partial-') as folder:
    work=Path(folder)
    for name in ('Commons','Ui','services'):(work/name).symlink_to(SHELL/name,target_is_directory=True)
    for source in [*ROOT.glob('*.qml'),ROOT/'Model.js']:shutil.copy2(source,work/source.name)
    (work/'doctor.py').write_text('''import json,sys
if sys.argv[1]=="scan":
 print(json.dumps({"schema":1,"type":"scan_start","total":16,"host":"Fixture"}),flush=True)
 print(json.dumps({"schema":1,"type":"check","completed":1,"result":{"id":"cpu","domain":"cpu","title":"CPU","state":"ok","summary":"Partial fixture","metrics":{}}}),flush=True)
 sys.exit(7)
else: print(json.dumps({"schema":1,"type":"history","samples":[],"scans":[]}))
''')
    (work/'shell.qml').write_text('''import QtQuick
import Quickshell
ShellRoot {
 Doctor {id:doctor;testMode:true}
 Timer {interval:100;running:true;onTriggered:{doctor.testMode=false;doctor.refresh(false)}}
 Timer {interval:1500;running:true;onTriggered:{console.log("PARTIAL_STATE "+doctor.status());Qt.quit()}}
}
''')
    p=subprocess.run(['qs','--no-color','--path',str(work/'shell.qml')],env={**os.environ,'QT_QPA_PLATFORM':'wayland'},capture_output=True,text=True,timeout=10)
    log=p.stdout+p.stderr
    (ROOT/'verification/partial-scan.log').write_text(log)
    assert p.returncode==0 and 'ERROR:' not in log,log
    state=json.loads(next(s.split('PARTIAL_STATE ',1)[1] for s in log.splitlines() if 'PARTIAL_STATE ' in s))
    assert not state['scanning'] and not state['complete'] and state['state']=='unknown',state
    assert len(state['results'])==1 and state['scanError'],state
    print('PASS: actual native collector exit 7 retains one result, marks incomplete, and cannot report healthy.')
