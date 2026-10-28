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
  answer=state if self.path=='/launch-status' else {'foregroundAppInfo':[{'appId':'com.webos.app.livedmost','windowGroupOwnerId':'com.webos.app.livetv','windowType':'_WEBOS_WINDOW_TYPE_CARD'}]} if self.path=='/foreground' else {}
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
  shell=engine.rootObjects()[0];shell.loadLaunchStatus();rp.wait(250)
  state['inspection']['fingerprint']='b'*64
  state['inspection']['issues']=[{'code':'launch_home_mapping','source':''}]
  shell.setProperty('ready',True);shell.loadLaunchStatus();rp.wait(250)
  english=shell.property('message');assert english.startswith('HOME configuration'),english
  shell.setProperty('systemLang','pl');rp.wait(250)
  assert 'Konfiguracja HOME' in shell.property('message'),shell.property('message')
  assert not posts,'Read-only status must never change launch mode'
  shell.setProperty('foreground',True);rp.wait(250)
  assert shell.property('nowTitle')=='TV',shell.property('nowTitle')
  print('PASS generated overlay bridge: read-only status, translated warnings, no POST, livedmost TV title')
finally:server.shutdown();server.server_close()
