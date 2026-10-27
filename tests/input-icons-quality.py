"""Compare output-scaled icons against a direct high-resolution mask reference.

The embedded pre-fix Canvas is the regression fixture: it loses detail at 48px.
The reference does not go through either QML implementation.
"""
import os,tempfile,json
from pathlib import Path
from PySide6.QtCore import Qt,QUrl,QEventLoop,QTimer,QRectF
from PySide6.QtGui import QGuiApplication,QImage,QPainter,QColor,QFont
from PySide6.QtQuick import QQuickView
r=Path(__file__).resolve().parents[1];out=r/'dist/icon-audit';out.mkdir(parents=True,exist_ok=True)
a=QGuiApplication([])
def wait():
 e=QEventLoop();QTimer.singleShot(500,e.quit);e.exec()
ids=['apple-tv','xbox','hdmi','wiim','shield','tv-screen']
with tempfile.TemporaryDirectory() as tmp:
 d=Path(tmp);(d/'input-icons').symlink_to(r/'ui/input-icons',target_is_directory=True)
 (d/'Before.qml').write_text('import QtQuick 2.6\n\n// Tint a local PNG on the CPU: no SVG plugin or shader effect is required.\nCanvas {\n    id: glyph\n    property string iconId: "hdmi"\n    property color ink: "white"\n    property url imageUrl: Qt.resolvedUrl("input-icons/" + iconId + ".png")\n    property url loadedUrl: ""\n    function loadMask() {\n        if (loadedUrl.toString() !== "") unloadImage(loadedUrl);\n        loadedUrl = imageUrl;\n        loadImage(imageUrl);\n        requestPaint();\n    }\n    Component.onCompleted: loadMask()\n    onImageUrlChanged: loadMask()\n    onImageLoaded: requestPaint()\n    onInkChanged: requestPaint()\n    onWidthChanged: requestPaint()\n    onHeightChanged: requestPaint()\n    onPaint: {\n        var c = getContext("2d");\n        c.reset();\n        if (!isImageLoaded(imageUrl)) return;\n        c.drawImage(imageUrl, 0, 0, width, height);\n        c.globalCompositeOperation = "source-in";\n        c.fillStyle = ink;\n        c.fillRect(0, 0, width, height);\n    }\n}\n')
 (d/'After.qml').write_text((r/'ui/DeviceIcon.qml').read_text())
 content=['import QtQuick 2.6','Rectangle { width: 900; height: 800; color: "#25282d"']
 for i,id in enumerate(ids):
  for col,component in enumerate(['Before','After']):
   content.append(f'{component} {{ x: {50+col*420}; y: {30+i*125}; width: 48; height: 48; scale: 2.2; transformOrigin: Item.TopLeft; iconId: "{id}"; ink: "white" }}')
 content.append('}')
 (d/'main.qml').write_text('\n'.join(content));v=QQuickView();v.setSource(QUrl.fromLocalFile(str(d/'main.qml')));assert v.status()==QQuickView.Ready,v.errors();v.show();wait();frame=v.grabWindow();frame.save(str(out/'quality-before-after.png'))
 # Compare to the high-resolution mask filtered directly to the final size.
 # This models the focus scale plus UHD output without an intermediate 48px raster.
 ratio=frame.width()/900;metrics=[]
 for i,id in enumerate(ids):
  errors=[]
  side=round(48*2.2*ratio)
  ref=QImage(side,side,QImage.Format_ARGB32_Premultiplied);ref.fill(QColor('#25282d'));p=QPainter(ref);p.setRenderHint(QPainter.SmoothPixmapTransform);mask=QImage(str(d/'input-icons'/(id+'.png')));t=QPainter(mask);t.setCompositionMode(QPainter.CompositionMode_SourceIn);t.fillRect(mask.rect(),QColor('white'));t.end();p.drawImage(QRectF(0,0,side,side),mask);p.end()
  for col in [0,1]:
   actual=frame.copy(round((50+col*420)*ratio),round((30+i*125)*ratio),side,side)
   # Source RGB may be black; compare alpha-shaped luminance against white.
   error=0
   for y in range(side):
    for x in range(side):
     error+=abs(actual.pixelColor(x,y).red()-ref.pixelColor(x,y).red())
   errors.append(error/(side*side))
  metrics.append({'id':id,'beforeMAE':errors[0],'afterMAE':errors[1]})
 assert all(m['afterMAE'] < m['beforeMAE']*0.8 for m in metrics),metrics
 print('PASS six representative icons retain edges at 2.2x output/focus scale'); print(json.dumps(metrics,indent=2));(out/'quality-metrics.json').write_text(json.dumps(metrics,indent=2)+'\n')
