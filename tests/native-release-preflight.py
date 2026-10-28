"""Direct overlay installer must enforce the native flags too, before installation."""
import importlib.util,re,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
s=importlib.util.spec_from_file_location('tv',ROOT/'tests/mode-switch.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
for arg in (['--native-home','--keep-lg-home'],['--native-home','--replace-lg-home'],['--home-key=773'],['--home-key-exec'],['--keep-lg-home','--native-home']):
 t=m.TV(mapper=False)
 try:
  t.put('/bin/id','#!/bin/sh\necho 0\n');t.p('/bin/id').chmod(0o755)
  t.put('/media/developer/apps/usr/palm/services/org.webosbrew.hbchannel.service/elevate-service','#!/bin/sh\nexit 0\n');t.p('/media/developer/apps/usr/palm/services/org.webosbrew.hbchannel.service/elevate-service').chmod(0o755)
  code=(ROOT/'webos10/install.sh').read_text()
  code=re.sub(r'(?<![\w/])(?:/var/lib/|/media/developer/|/etc/starfish-release)',lambda v:str(t.root)+v[0],code)
  t.put('/incoming/install.sh',code)
  result=subprocess.run(['sh',str(t.p('/incoming/install.sh')),*arg],env=t.env,capture_output=True,text=True)
  assert result.returncode!=0 and 'cannot be combined' in result.stderr,(arg,result.stdout,result.stderr)
 finally:t.clean()
# What the panel's updater passes on webOS 10 must never be refused as a conflict:
# --replace-lg-home only means "keep the setup", and --keep-lg-home chooses the
# compatibility overlay.
for arg in (['--replace-lg-home'],['--keep-lg-home']):
 t=m.TV(mapper=False)
 try:
  t.put('/bin/id','#!/bin/sh\necho 0\n');t.p('/bin/id').chmod(0o755)
  t.put('/media/developer/apps/usr/palm/services/org.webosbrew.hbchannel.service/elevate-service','#!/bin/sh\nexit 0\n');t.p('/media/developer/apps/usr/palm/services/org.webosbrew.hbchannel.service/elevate-service').chmod(0o755)
  code=(ROOT/'webos10/install.sh').read_text()
  code=re.sub(r'(?<![\w/])(?:/var/lib/|/media/developer/|/etc/starfish-release)',lambda v:str(t.root)+v[0],code)
  t.put('/incoming/install.sh',code)
  result=subprocess.run(['sh',str(t.p('/incoming/install.sh')),*arg],env=t.env,capture_output=True,text=True)
  assert 'cannot be combined' not in result.stderr,(arg,result.stdout,result.stderr)
 finally:t.clean()
print('PASS direct native installer rejects incompatible Home/key options before install')
