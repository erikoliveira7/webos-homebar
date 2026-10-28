"""Exercise the shared settings menu in Qt, without any TV transport."""
import importlib.util, tempfile
from pathlib import Path
from PySide6.QtCore import QUrl, Qt, QPoint
from PySide6.QtGui import QGuiApplication
from PySide6.QtQuick import QQuickView
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
        if (shell.notice !== "" || shell.modeConfirm !== "overlay") throw Error("first OK must preview");
        shell.navigateMenu(Qt.Key_Return);
        if (shell.notice !== "mode:overlay") throw Error("second OK did not apply");
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
    function resetNotice() { shell.notice = ""; }
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
 view.grabWindow().save(str(out/'settings-mode-preview.png'))
 QTest.mouseClick(view,Qt.LeftButton,pos=QPoint(1100,348));rp.wait(100)
 assert root.resultNotice()=='mode:overlay'
 root.resetNotice()
 QTest.keyClick(view,Qt.Key_Return);rp.wait(100);assert root.resultNotice()==''
 QTest.keyClick(view,Qt.Key_Return);rp.wait(100)
 assert root.resultNotice()=='mode:overlay'
 print('PASS Qt menu: hidden on Home panel, current selection, hover/arrows inert, OK commits, cancel/busy/no-op, capability filtering')
