"""Actual top-level installer decisions with disposable TV paths and stub installers."""
import importlib.util, json, re, subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
s=importlib.util.spec_from_file_location('mode_shell',ROOT/'tests/mode-switch.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
def run(release='10.3.1',panel=False,setup=lambda t:None,expected='native',args=()):
 t=m.TV(release=release,mapper=False)
 try:
  setup(t);bundle=t.p('/bundle');(bundle/'webos10').mkdir(parents=True);(bundle/'webos4').mkdir()
  script=(ROOT/'install.sh').read_text()
  script=re.sub(r'(?<![\w/])(?:/var/lib/|/etc/starfish-release)',lambda v:str(t.root)+v[0],script)
  (bundle/'install.sh').write_text(script)
  (bundle/'webos10/integration.js').write_text(t.p(m.BASE+'/integration.js').read_text())
  (bundle/'probe.sh').write_text('if [ "$1" = panel ]; then exit '+('0' if panel else '1')+'; fi\nif [ "$1" = native-home ]; then node "$(dirname "$0")/webos10/integration.js" check; exit $?; fi\nexit 0\n')
  (bundle/'webos10/install.sh').write_text('echo OVERLAY_ARGS:$*\n')
  (bundle/'webos4/install.sh').write_text('echo PANEL_INSTALL\n')
  result=subprocess.run(['sh',str(bundle/'install.sh'),*args],env=dict(t.env,HOMEBAR_WEBOS=release),text=True,capture_output=True,timeout=8)
  if expected=='blocked':
   assert result.returncode!=0 and 'OVERLAY_ARGS:' not in result.stdout and 'PANEL_INSTALL' not in result.stdout,(result.stdout,result.stderr)
   return result.stdout+result.stderr
  assert result.returncode==0,(result.stdout,result.stderr)
  output=result.stdout
  if expected=='panel':assert 'PANEL_INSTALL' in output,output
  else:
   assert 'OVERLAY_ARGS:' in output,output
   assert ('--native-home' in output)==(expected=='native'),output
   assert '--additional-overlay' not in output,output
  return output
 finally:t.clean()
def magic(t,key='home'):
 t.put('/home/root/magic_mapper.py','VERSION = "1.1.0"\ndef get_button_map(): magic_mapper_config.json\ndef launch_app(inputs): pass')
 t.put('/home/root/magic_mapper_config.json',json.dumps({key:{'function':'launch_app','inputs':{'app_id':'org.rawin.launcher'}}}))
 t.put('/var/lib/webosbrew/init.d/start_magic_mapper','SCRIPT='+str(t.p('/home/root/magic_mapper.py'))+'\nPYTHON_PIDFILE=/tmp/magic_mapper_python.pid\nrestart)\n')
run('6.5.0',setup=magic,expected='legacy')
run();run('11.0.0');run('4.10.2',panel=True,expected='panel');run('5.6.2',panel=True,expected='panel')
run('6.5.0',expected='legacy');run('9.0.0',expected='legacy')
run(setup=lambda t:t.foreign(),expected='blocked')
run(setup=lambda t:t.put(m.KEYS,json.dumps({'773':{'action':'launch','id':'other.launcher'}})),expected='blocked')
run(setup=lambda t:t.put('/home/root/magic_mapper.py','unknown fork'),expected='blocked')
run(setup=lambda t:t.put(m.BASE+'/VERSION','0.17.2'),expected='native')
run(setup=magic,expected='native')
run('4.10.0',setup=lambda t:t.put('/var/lib/webosbrew/rawin-launcher/VERSION','0.17.2'),expected='panel')
run(args=('--overlay',),expected='native');run(args=('--native-home',),expected='native')
run(args=('--additional-overlay',),expected='blocked')
# What the panel's updater passes on webOS 10/11 (no TV may be refused by it):
run(args=('--overlay','--replace-lg-home'),expected='native');run('11.0.0',args=('--overlay','--replace-lg-home'),expected='native')
run(setup=lambda t:t.put(m.BASE+'/VERSION','0.18.0'),args=('--overlay','--replace-lg-home'),expected='native')
# Keeping LG's Home stays on the compatibility overlay: asked for, or chosen by an earlier install.
run(args=('--overlay','--keep-lg-home'),expected='legacy')
run(setup=lambda t:t.put(m.BASE+'/keep-lg-home',''),args=('--overlay','--replace-lg-home'),expected='legacy')
run(setup=lambda t:t.put(m.BASE+'/keep-lg-home',''),expected='legacy')
run(args=('--native-home','--keep-lg-home'),expected='blocked');run(args=('--native-home','--replace-lg-home'),expected='blocked')
run(setup=lambda t:t.put(m.BASE+'/additional-overlay',''),expected='blocked')
print('PASS release install policies (incl. the panel updater options): native defaults/upgrades, ribbon, legacy, blocked conflicts and deferred mode')
