"""Exercise the shared settings menu in Qt, without any TV transport."""
import importlib.util, tempfile
from pathlib import Path
from PySide6.QtCore import QUrl, Qt, QPoint, QPointF
from PySide6.QtGui import QGuiApplication
from PySide6.QtQuick import QQuickView, QQuickItem
from PySide6.QtTest import QTest
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('render',ROOT/'tools/render-panel.py');rp=importlib.util.module_from_spec(spec);spec.loader.exec_module(rp)
app=QGuiApplication([])
with tempfile.TemporaryDirectory() as tmp:
 d=Path(tmp);rp.panel(d)
 main=rp.MAIN % (1920,1080)
 main=main.replace('    function glow()', '''    property string result: ""
    function info(current, supported, busy) {
        return {available:true,nativeSupported:supported,current:current,busy:busy,
            inspection:{issues:[],blockers:[],cleanup:0,owner:current === "native" ? "native" : "lg",fingerprint:"qt",migrationAvailable:false}};
    }
    function test() {
        shell.ready = true;
        if (shell.settingKeys.indexOf("mode") !== -1) throw Error("mode on Home panel");
        shell.settings = shell.validSettings({exitTo:"com.webos.app.livetv"});
        if (shell.settings.exitTo !== "com.webos.app.livetv") throw Error("TV return target discarded");
        var returns = shell.optionsFor("exitTo", shell.lang, shell.allInputs);
        if (!returns.some(function(o) {return o.id === "com.webos.app.livetv";})) throw Error("TV return target missing");
        shell.modeInfo = info("native",true,false);
        shell.settings = shell.validSettings({lang:"pl"});
        shell.page = "settings"; shell.selected = shell.settingKeys.indexOf("mode");
        shell.enterValues();
        if (shell.valueIndex !== 0) throw Error("current value");
        shell.notice = "";
        shell.navigateMenu(Qt.Key_Down);
        if (shell.notice !== "") throw Error("arrow switched mode");
        shell.valueHover = 0;
        if (shell.notice !== "") throw Error("hover switched mode");
        shell.navigateMenu(Qt.Key_Return);
        if (shell.notice !== "" || shell.modeConfirm !== "overlay") throw Error("OK must open the popup");
        if (shell.modeConfirmYes) throw Error("popup must open on No");
        shell.answerMode(false);
        if (shell.notice !== "" || shell.modeConfirm !== "") throw Error("No applied or kept the popup");
        shell.navigateMenu(Qt.Key_Return); shell.answerMode(true);
        if (shell.notice !== "mode:overlay") throw Error("Yes did not apply");
        if (shell.modeDescription("native") === shell.modeDescription("overlay") || shell.modeDescription("native") === "") throw Error("descriptions");
        if (shell.t("val_mode_native").indexOf("(") < 0) throw Error("native name lacks its qualifier");
        shell.notice = ""; shell.modeInfo = info("native",true,true);
        shell.chooseMode(); if (shell.notice !== "") throw Error("busy request");
        shell.modeInfo = info("native",true,false);
        shell.valueIndex = 0; shell.chooseMode(); if (shell.notice !== "") throw Error("same mode request");
        shell.valueIndex = 1; shell.navigateMenu(Qt.Key_Left);
        if (shell.notice !== "" || shell.pane !== 0) throw Error("cancel applied mode");
        shell.modeInfo = info("legacy",false,false);
        if (shell.valueOptions.length !== 1 || shell.valueOptions[0].id !== "overlay") throw Error("unsupported native option");
        shell.modeInfo = info("native",true,false);
        shell.enterValues(); shell.valueIndex = 1; shell.notice = "";
        shell.forceActiveFocus();
        result = "PASS";
    }
    function showDone(ok) { shell.modeDoneOk = ok; shell.modeDoneAt = 123; shell.forceActiveFocus(); }
    function doneState() { return shell.modeDoneAt + '|' + shell.settings.modeAck; }
    function nativePopup() { shell.modeInfo = info('overlay',true,false); shell.modeInfo.inspection.cleanup = 2; shell.modeInfo.inspection.mapped = [{source:'Input Hook',key:'1'},{source:'Input Hook',key:'2'}]; shell.modeConfirm = 'native'; }
    function popupText() { return shell.modePopupText('native'); }
    function resetNotice() { shell.notice = ""; }
    function focusValues() { shell.menuHover = -1; shell.valueHover = -1; shell.pane = 1; shell.valueIndex = 1; shell.forceActiveFocus(); }
    function resultNotice() { return shell.notice; }
    function glow()''')
 (d/'main.qml').write_text(main)
 view=QQuickView();view.setSource(QUrl.fromLocalFile(str(d/'main.qml')))
 assert view.status()==QQuickView.Ready,view.errors()
 view.show();rp.wait(250);root=view.rootObject();root.test();assert root.property('result')=='PASS'
 # Real desktop pointer and keyboard events exercise the TV menu handlers.
 rp.wait(500)
 out=ROOT/'dist/render-modes';out.mkdir(parents=True,exist_ok=True)
 view.grabWindow().save(str(out/'settings-mode.png'))
 QTest.mouseMove(view,QPoint(1100,348));rp.wait(100);assert root.resultNotice()==''
 QTest.mouseClick(view,Qt.LeftButton,pos=QPoint(1100,348));rp.wait(100);assert root.resultNotice()==''
 view.grabWindow().save(str(out/'settings-mode-popup.png'))
 def center(name):
  def find(it):
   if it.objectName()==name:return it
   for c in it.childItems():
    r=find(c)
    if r is not None:return r
  item=find(view.rootObject());assert item is not None and item.isVisible(),name
  p=item.mapToScene(QPointF(item.width()/2,item.height()/2));return QPoint(int(p.x()),int(p.y()))
 # No on the pointer cancels; the same popup answers Yes on a click.
 QTest.mouseClick(view,Qt.LeftButton,pos=center('modeNo'));rp.wait(100);assert root.resultNotice()==''
 QTest.mouseClick(view,Qt.LeftButton,pos=QPoint(1100,348));rp.wait(100)
 QTest.mouseClick(view,Qt.LeftButton,pos=center('modeYes'));rp.wait(100)
 assert root.resultNotice()=='mode:overlay'
 root.resetNotice();root.focusValues()
 # Keys: OK opens the popup, OK on its default (No) cancels, LEFT then OK applies, BACK cancels.
 QTest.keyClick(view,Qt.Key_Return);rp.wait(100);assert root.resultNotice()==''
 QTest.keyClick(view,Qt.Key_Return);rp.wait(100);assert root.resultNotice()==''
 QTest.keyClick(view,Qt.Key_Return);rp.wait(100);QTest.keyClick(view,Qt.Key_Escape);rp.wait(100);assert root.resultNotice()==''
 QTest.keyClick(view,Qt.Key_Return);rp.wait(100)
 QTest.keyClick(view,Qt.Key_Left);rp.wait(100);QTest.keyClick(view,Qt.Key_Return);rp.wait(100)
 assert root.resultNotice()=='mode:overlay'
 # The popup of a native switch names the mappings that go; the note after a switch is shown once.
 root.resetNotice();root.nativePopup();rp.wait(150);assert 'Input Hook' in root.popupText() and 'Magic Mapper' not in root.popupText(),root.popupText();view.grabWindow().save(str(out/'settings-mode-popup-native.png'))
 QTest.keyClick(view,Qt.Key_Escape);rp.wait(100);assert root.resultNotice()==''
 root.showDone(True);rp.wait(150);view.grabWindow().save(str(out/'settings-mode-done.png'))
 assert root.doneState()=='123|0',root.doneState()
 QTest.keyClick(view,Qt.Key_Return);rp.wait(100);assert root.doneState()=='0|123',root.doneState()
 root.showDone(False);rp.wait(150);view.grabWindow().save(str(out/'settings-mode-failed.png'))
 QTest.keyClick(view,Qt.Key_Escape);rp.wait(100);assert root.doneState()=='0|123',root.doneState()
 print('PASS Qt menu: hidden on Home panel, current selection, hover/arrows inert, OK opens a Yes/No popup (No by default), Yes commits, cancel/busy/no-op, capability filtering')
