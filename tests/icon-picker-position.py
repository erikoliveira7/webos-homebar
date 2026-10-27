"""Regress popup anchoring against actual rendered delegate geometry."""
from pathlib import Path
import importlib.util,tempfile,json
from PySide6.QtCore import QUrl,Qt,QCoreApplication,QEvent
from PySide6.QtGui import QGuiApplication,QKeyEvent
from PySide6.QtQuick import QQuickView,QQuickItem
r=Path(__file__).resolve().parents[1];s=importlib.util.spec_from_file_location('render',r/'tools/render-panel.py');rp=importlib.util.module_from_spec(s);s.loader.exec_module(rp);app=QGuiApplication([])
for width,height in [(1920,1080),(1280,720)]:
 with tempfile.TemporaryDirectory() as t:
  d=Path(t);rp.panel(d);p=d/'Launcher.qml';p.write_text(p.read_text().rstrip()[:-1]+'''function actualCenter() { var c=sourceCells.itemAt(editSourceIndex); return c ? c.mapToItem(shell,c.width/2,0).x : -1; } }''');p=d/'FavouriteStore.qml';p.write_text(p.read_text().replace('rawinLauncher','pickerAnchor'+str(width)))
  (d/'main.qml').write_text((rp.MAIN%(width,height)).rstrip()[:-1]+'function evaluate(code) {return JSON.stringify(eval(code));} }')
  v=QQuickView();v.engine().setOfflineStoragePath(str(d/'storage'));v.setSource(QUrl.fromLocalFile(str(d/'main.qml')));assert v.status()==QQuickView.Ready,v.errors();v.show();rp.wait(120);root=v.rootObject()
  def js(code):return json.loads(root.evaluate(code))
  def key(code):
   QCoreApplication.sendEvent(v,QKeyEvent(QEvent.KeyPress,code,Qt.NoModifier));QCoreApplication.sendEvent(v,QKeyEvent(QEvent.KeyRelease,code,Qt.NoModifier));rp.wait(30)
  for favs in [0,3,7]:
   for mode in ['icon','iconCec']:
    root.scene(json.dumps(dict(page='home',favs=[a[0] for a in rp.APPS[:favs]],inputs=rp.inputs(rp.INPUTS),settings={'lang':'pl','tv':True,'motion':False,'inputText':mode},editSource=1)));js('shell.ready=true;shell.forceActiveFocus();shell.editInputIcon=true');rp.wait(100)
    picker=root.findChild(QQuickItem,'inputIconPicker')
    for step in range(8):
     if step in [2,4,6]:js('shell.editSourceIndex='+str({2:0,4:4,6:1}[step])+';shell.editInputIcon=true')
     key(Qt.Key_Right)
     actual=js('shell.actualCenter()');expected=max(js('shell.margin'),min(width-js('shell.margin')-picker.width(),actual-picker.width()/2))
     assert abs(picker.x()-expected)<1,(width,favs,mode,step,picker.x(),expected,actual)
  v.close();v.deleteLater();QCoreApplication.sendPostedEvents(None,QEvent.DeferredDelete)
print('PASS picker anchor FHD/HD,0/3/7favourites,icon/text layouts and repeated icon cycling')
