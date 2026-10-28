"""Run the real root shell scripts in a disposable TV filesystem, never over SSH."""
import json, os, re, shutil, signal, subprocess, tempfile, time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
BASE='/var/lib/webosbrew/rawin-launcher-home'
APP='/media/developer/apps/usr/palm/applications/org.rawin.launcher'
HOME='/usr/palm/applications/com.webos.app.home'
STORE='/home/root/.local/share'
KEYS='/home/root/.config/lginputhook/keybinds.json'
DB='9969c85c6e1c20a73a4ac456d46e31f7'
class TV:
 def __init__(self, mode='legacy', release='10.3.1', mapper=True):
  self.tmp=tempfile.TemporaryDirectory(prefix='homebar-mode-'); self.root=Path(self.tmp.name)
  self.env=dict(os.environ, TV_ROOT=str(self.root),PATH=str(self.root/'bin')+':'+os.environ['PATH'])
  for p in [BASE+'/app',BASE+'/native-app',APP,HOME,'/bin','/proc','/etc','/var/lib/tvweb','/tmp']:(self.p(p)).mkdir(parents=True,exist_ok=True)
  self.put('/usr/bin/qml-runner','runner');self.put('/etc/starfish-release','release '+release);self.put('/proc/mounts','');self.put('/proc/uptime','50.00 10.00')
  self.put(APP+'/appinfo.json',json.dumps({'id':'org.rawin.launcher','type':'qml'}));self.put(APP+'/Config.js','var exitTarget = true;\nvar platform = "overlay";\n')
  for f in ['main.qml','Panel.qml','FavouriteStore.qml','Strings.js','Themes.js','About.js','icon.png']:self.put(APP+'/'+f,'test')
  (self.p(APP+'/fonts')).mkdir()
  self.put(BASE+'/app/appinfo.json','{"type":"web"}');self.put(HOME+'/appinfo.json','{"type":"flutter"}')
  for id,value in [('org.rawin.launcher','app-data'),('com.webos.app.home','old-home-data')]:
   for suffix in ['sqlite','ini','sqlite-wal','sqlite-shm']:self.put(STORE+'/'+id+'/QML/OfflineStorage/Databases/'+DB+'.'+suffix,value+'-'+suffix)
  if mapper:self.put(KEYS,json.dumps({'773':{'action':'launch','id':'org.rawin.launcher'},'1042':{'action':'launch','id':'other.app'},'500':{'action':'launch','id':'org.rawin.launcher'}}))
  for src,dst in [('mode-switch.sh','mode-switch.sh'),('native-home.sh','native-home.sh'),('home-takeover.sh','takeover.sh'),('integration.js','integration.js'),('uninstall.sh','uninstall.sh')]:
   s=(ROOT/'webos10'/src).read_text()
   s=re.sub(r'(?<![\w/])(?:/var/lib/|/media/developer/|/usr/palm/|/usr/bin/qml-runner|/usr/bin/com.webos.app.home|/home/root/|/etc/starfish-release|/proc/|/tmp/)',lambda m:str(self.root)+m[0],s)
   s=s.replace("readdirSync('/proc')", "readdirSync('"+str(self.root)+"/proc')")
   s=s.replace('ls -di ', 'ls -diL ')
   self.put(BASE+'/'+dst,s)
  shutil.copyfile(ROOT/'webos10/native-stage.js',self.p(BASE+'/native-stage.js'))
  # Fake only system boundaries; migrations, keys, journal and decisions are real.
  self.put('/bin/luna-send', '''#!/usr/bin/env python3
import os,sys,json,time
from pathlib import Path
r=Path(os.environ['TV_ROOT']);a=sys.argv;uri=a[-2];params=json.loads(a[-1])
with (r/'calls').open('a') as f:f.write(uri+' '+a[-1]+'\\n')
if uri.endswith('/launch') and (r/'pause-launch').exists():
 (r/'paused').touch()
 while (r/'pause-launch').exists():time.sleep(.02)
if uri.endswith('/launch') and (r/'fail-launch').exists():
 (r/'fail-launch').unlink();print('{"returnValue":false}');sys.exit(0)
if uri.endswith('/dev/remove'):
 (r/'media/developer/apps/usr/palm/applications/org.rawin.launcher/appinfo.json').unlink(missing_ok=True);print('{"returnValue":true}');sys.exit(0)
if uri.endswith('/dev/install'):print('{"state":"installed"}');sys.exit(0)
if uri.endswith('/getAppInfo'):
 info=json.loads((r/'usr/palm/applications/com.webos.app.home/appinfo.json').read_text());print(json.dumps({'returnValue':True,'appInfo':info}))
else:print('{"returnValue":true}')
''')
  self.put('/bin/mount','''#!/usr/bin/env python3
import os,sys
from pathlib import Path
r=Path(os.environ['TV_ROOT']);src=Path(sys.argv[-2]);dst=Path(sys.argv[-1])
if (r/'fail-mount').exists(): (r/'fail-mount').unlink();sys.exit(1)
dst.rename(str(dst)+'.stock');dst.symlink_to(src);(r/'proc/mounts').write_text('fake '+str(dst)+' none rw 0 0\\n')
''')
  self.put('/bin/umount','''#!/usr/bin/env python3
import os,sys
from pathlib import Path
r=Path(os.environ['TV_ROOT']);dst=Path(sys.argv[-1])
if (r/'fail-umount').exists(): (r/'fail-umount').unlink();sys.exit(1)
dst.unlink();Path(str(dst)+'.stock').rename(dst);(r/'proc/mounts').write_text('')
''')
  for name in ['sleep','logger','pidof','kill']:self.put('/bin/'+name,'#!/bin/sh\nexit 0\n')
  for p in (self.root/'bin').iterdir():p.chmod(0o755)
  if mode=='native':
   self.run_native('enable'); self.put(STORE+'/com.webos.app.home/QML/OfflineStorage/Databases/'+DB+'.sqlite','latest-native-data')
  if mode=='overlay':self.switch('overlay')
 def p(self,p):return self.root/p.lstrip('/')
 def put(self,p,s):p=self.p(p);p.parent.mkdir(parents=True,exist_ok=True);p.write_text(s)
 def run(self,script,arg,ok=True):
  r=subprocess.run(['sh',str(self.p(BASE+'/'+script)),arg],env=self.env,text=True,capture_output=True,timeout=20)
  if ok:assert r.returncode==0,(arg,r.stdout,r.stderr)
  else:assert r.returncode!=0,(arg,r.stdout,r.stderr)
  return r
 def switch(self,mode,ok=True):return self.run('mode-switch.sh',mode,ok)
 def run_native(self,mode):return self.run('native-home.sh',mode)
 def keys(self):return json.loads(self.p(KEYS).read_text())
 def foreign(self):
  self.put('/foreign/appinfo.json','{"type":"qml"}')
  subprocess.run(['mount','--bind',str(self.p('/foreign')),str(self.p(HOME))],env=self.env,check=True)
 def clean(self):self.tmp.cleanup()

def test():
 count=0
 for old in ['legacy','native']:
  t=TV(old)
  try:
   before=t.p(STORE+'/'+('com.webos.app.home' if old=='native' else 'org.rawin.launcher')+'/QML/OfflineStorage/Databases/'+DB+'.sqlite').read_bytes()
   t.switch('native');assert t.p(BASE+'/native-home').exists() and t.p(HOME).is_symlink()
   assert t.p(STORE+'/com.webos.app.home/QML/OfflineStorage/Databases/'+DB+'.sqlite').read_bytes()==before
   assert t.keys()['1042']['id']=='other.app'
   assert not any(v.get('id')=='org.rawin.launcher' for v in t.keys().values())
   t.switch('native');t.switch('overlay',False)
   assert t.p(BASE+'/native-home').exists();count+=1
  finally:t.clean()
 for fail in ['fail-mount','fail-launch']:
  t=TV();before=t.p(KEYS).read_bytes()
  try:
   t.put('/'+fail,'');t.switch('native',False)
   assert not t.p(BASE+'/native-home').exists();assert t.p(KEYS).read_bytes()==before
   assert not t.p(BASE+'/mode-switch-lock').exists();count+=1
  finally:t.clean()
 for release in ['4.10.2','6.5.0','9.0.0']:
  t=TV(release=release)
  try:t.switch('native',False);assert not t.p(HOME).is_symlink();count+=1
  finally:t.clean()
 t=TV()
 try:
  t.foreign();before=t.p(KEYS).read_bytes();t.switch('native',False)
  assert t.p(KEYS).read_bytes()==before;count+=1
 finally:t.clean()
 print('PASS',count,'native migration cases: old/new data, mappings, rollback, unsupported TV, foreign HOME and no companion switch')
if __name__=='__main__':test()
