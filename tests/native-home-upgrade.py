"""An older experimental installation has no installed integration module yet."""
import importlib.util, shutil, subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
s=importlib.util.spec_from_file_location('mode_shell',ROOT/'tests/mode-switch.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
t=m.TV('native')
try:
 incoming=t.p('/tmp/incoming');incoming.mkdir()
 for name in ['native-home.sh','integration.js']:
  shutil.copyfile(t.p(m.BASE+'/'+name),incoming/name)
 t.p(m.BASE+'/integration.js').unlink()
 r=subprocess.run(['sh',str(incoming/'native-home.sh'),'check-owner'],env=t.env,capture_output=True,text=True)
 assert r.returncode==0,(r.stdout,r.stderr)
 assert t.p(m.HOME).is_symlink()
 print('PASS incoming native Home ownership check with no installed integration module')
finally:t.clean()
