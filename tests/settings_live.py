import json,subprocess,time
from pathlib import Path
out=Path(__file__).resolve().parents[1]/'verification'
def status():return json.loads(subprocess.check_output(['omarchy-shell','nixfred.doctor','status'],text=True,timeout=8))
def entry():
 config=json.loads((Path.home()/'.config/omarchy/shell.json').read_text())
 return next(e for rows in config['bar']['layout'].values() for e in rows if e['id']=='nixfred.doctor')
try:
 for value in [False,True]:
  subprocess.run(['omarchy','bar','set','nixfred.doctor','motion',json.dumps(value),'--json'],check=True,timeout=15)
  for i in range(20):
   s=status()
   if s['motion'] is value:break
   time.sleep(.2)
  assert s['motion'] is value and entry()['motion'] is value,(s,entry())
 (out/'settings-verification.json').write_text(json.dumps({'public_api_persistence_and_live_readback':True,'reduced_then_animated':True,'settings':entry(),'physical_button_clicks_tested':False},indent=2))
 print('PASS: public API persists motion settings and the live plugin responds; animations restored.')
finally:
 if entry().get('motion') is not True:subprocess.run(['omarchy','bar','set','nixfred.doctor','motion','true','--json'],check=True,timeout=15)
