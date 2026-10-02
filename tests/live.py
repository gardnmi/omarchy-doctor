import json,subprocess,time
from pathlib import Path
out=Path(__file__).resolve().parents[1]/'verification'
def ipc(*args):return subprocess.check_output(['omarchy-shell','nixfred.doctor',*args],text=True,timeout=8)
def status():return json.loads(ipc('status'))
def ready(previous=0):
 for i in range(50):
  s=status()
  if not s['scanning'] and s['complete'] and s['lastScan']>previous:return s
  time.sleep(.5)
 raise AssertionError(s)
ipc('open');s=ready()
assert s['width']>0 and s['height']>0 and len(s['results'])==16,s
(out/'installed-quick-status.json').write_text(json.dumps(s,indent=2))
ipc('deepScan');s=ready(s['lastScan'])
assert len(s['results'])==16 and not s['scanError'],s
(out/'installed-deep-status.json').write_text(json.dumps(s,indent=2))
mon=next(m for m in json.loads(subprocess.check_output(['hyprctl','-j','monitors'],text=True)) if m['focused'])
for page in ['overview','findings','history','settings']:
 ipc('show',page);time.sleep(.65);s=status()
 assert s['opened'] and s['page']==page,s
 geometry=f"{round(mon['x']+s['panelX'])},{round(mon['y']+s['panelY'])} {round(s['panelWidth'])}x{round(s['panelHeight'])}"
 subprocess.run(['grim','-g',geometry,str(out/f'live-{page}.png')],check=True,timeout=8)
s=status();assert s['liveFresh'] and s['sampleCount']>=2 and s['scanCount']>=2,s
(out/'installed-open-status.json').write_text(json.dumps(s,indent=2))
ipc('close');time.sleep(1)
s=status();assert not s['opened'] and not s['liveFresh'],s
(out/'installed-closed-status.json').write_text(json.dumps(s,indent=2))
p=Path.home()/'.config/omarchy/plugins/nixfred.doctor/doctor.py'
export=json.loads(subprocess.check_output(['python3',str(p),'export'],text=True,timeout=8))
assert export['type']=='export',export
report=Path(export['path']);json.loads(report.read_text());assert report.stat().st_mode&0o777==0o600
(out/'export-verification.json').write_text(json.dumps({'event':export,'mode':oct(report.stat().st_mode&0o777),'bytes':report.stat().st_size},indent=2))
print(json.dumps({'version':s['version'],'checks':len(s['results']),'counts':s['counts'],'samples':s['sampleCount'],'scans':s['scanCount'],'export':str(report),'pages_captured':4,'closed':not s['opened']},indent=2))
