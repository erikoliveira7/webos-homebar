"""Load the generated overlay and exercise its real HTTP bridge locally."""
import importlib.util, json, tempfile, threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from PySide6.QtCore import QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
ROOT=Path(__file__).resolve().parents[1]
def module(name,path):
 s=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
rp=module('render',ROOT/'tools/render-panel.py');build=module('build',ROOT/'tools/build.py')
state={'available':True,'nativeSupported':True,'current':'native','busy':False,'inspection':{'issues':[],'blockers':[],'fingerprint':'a'*64}};posts=[]
class Handler(BaseHTTPRequestHandler):
 def log_message(self,*args):pass
 def do_GET(self):
  answer=state if self.path=='/mode' else {'foregroundAppInfo':[{'appId':'com.webos.app.livedmost','windowGroupOwnerId':'com.webos.app.livetv','windowType':'_WEBOS_WINDOW_TYPE_CARD'}]} if self.path=='/foreground' else {}
  self.send_response(200);self.end_headers();self.wfile.write(json.dumps(answer).encode())
 def do_POST(self):
  # Qt appends a charset; the helper accepts MIME parameters too.
  assert self.headers.get_content_type()=='application/json'
  posts.append((self.path,json.loads(self.rfile.read(int(self.headers['Content-Length'])))))
  state['busy']=True;self.send_response(200);self.end_headers();self.wfile.write(b'{"ok":true,"pending":true}')
server=ThreadingHTTPServer(('127.0.0.1',0),Handler);threading.Thread(target=server.serve_forever,daemon=True).start()
app=QGuiApplication([])
try:
 with tempfile.TemporaryDirectory() as tmp:
  d=Path(tmp);rp.panel(d)
  q=build.panel_qml().replace('import QtGraphicalEffects 1.0','import Qt5Compat.GraphicalEffects').replace('import WebOS.Global 1.0','import "WebOS.js" as WebOS')
  q=q.replace('http://127.0.0.1:8899','http://127.0.0.1:'+str(server.server_port))
  (d/'Launcher.qml').write_text(q)
  engine=QQmlApplicationEngine();engine.load(QUrl.fromLocalFile(str(d/'Launcher.qml')));assert engine.rootObjects()
  shell=engine.rootObjects()[0];shell.loadMode();rp.wait(250)
  info=shell.property('modeInfo').toVariant();assert info['current']=='native' and info['available']
  shell.modeRun('overlay','a'*64);rp.wait(250);assert posts==[('/mode',{'mode':'overlay','fingerprint':'a'*64})]
  assert shell.property('modeInfo').toVariant()['busy']
  state.update(busy=False,result={'ok':False,'error':'launch_home_mapping'})
  rp.wait(1200);assert not shell.property('modeInfo').toVariant()['busy']
  assert shell.property('modeError')=='launch_home_mapping'
  state['inspection']['fingerprint']='b'*64
  state['inspection']['issues']=[{'code':'launch_button_setup','source':''}]
  shell.setProperty('ready',True);shell.loadMode();rp.wait(250)
  english=shell.property('message');assert english.startswith('Launch setup')
  shell.setProperty('systemLang','pl');rp.wait(250)
  assert shell.property('message')!=english and 'uruchamiania' in shell.property('message'),shell.property('message')
  shell.setProperty('foreground',True);rp.wait(250)
  assert shell.property('nowTitle')=='TV',shell.property('nowTitle')
  print('PASS generated overlay bridge: capability load, POST mode choice, poll after failed migration')
finally:server.shutdown();server.server_close()
