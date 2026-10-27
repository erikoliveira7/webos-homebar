#!/usr/bin/env python3
"""Regenerate vendored PNG masks from unchanged SVGs (requires PySide6).

Run with QT_QPA_PLATFORM=offscreen. No network; build.py uses committed PNGs.
Trim transparent margins and apply a modest optical correction to wide marks,
without stretching the artwork. The image slot is always square at runtime.
"""
import json,hashlib,math
from pathlib import Path
from PySide6.QtCore import Qt,QRectF
from PySide6.QtGui import QGuiApplication,QImage,QPainter
from PySide6.QtSvg import QSvgRenderer
ROOT=Path(__file__).resolve().parents[1]
app=QGuiApplication([])
folder=ROOT/'ui/input-icons'
manifest=json.loads((folder/'manifest.json').read_text())
report=[]
for entry in manifest['icons']:
    source=folder/(entry['id']+'.svg')
    assert hashlib.sha256(source.read_bytes()).hexdigest()==entry['sha256'],source
    renderer=QSvgRenderer(str(source));assert renderer.isValid(),source
    image=QImage(512,512,QImage.Format_ARGB32_Premultiplied);image.fill(Qt.transparent)
    painter=QPainter(image);box=renderer.viewBoxF();scale=min(480/box.width(),480/box.height())
    w,h=box.width()*scale,box.height()*scale
    renderer.render(painter,QRectF((512-w)/2,(512-h)/2,w,h));painter.end()
    pixels=[(x,y) for y in range(512) for x in range(512) if image.pixelColor(x,y).alpha()>8]
    assert pixels,source
    xs,ys=zip(*pixels);left=max(0,min(xs)-1);top=max(0,min(ys)-1)
    width=min(512,max(xs)+2)-left;height=min(512,max(ys)+2)-top
    ratio=min(width,height)/max(width,height)
    # Thin wordmarks need more width than dense square symbols to look balanced.
    edge=120 if ratio<0.45 else 112 if ratio<0.75 else 104
    art=image.copy(left,top,width,height).scaled(edge,edge,Qt.KeepAspectRatio,Qt.SmoothTransformation)
    output=QImage(128,128,QImage.Format_ARGB32_Premultiplied);output.fill(Qt.transparent)
    painter=QPainter(output);painter.drawImage((128-art.width())//2,(128-art.height())//2,art);painter.end()
    assert output.save(str(folder/(entry['id']+'.png')))
    report.append(dict(id=entry['id'],sourceBounds=[left,top,width,height],opticalEdge=edge,pngSize=[art.width(),art.height()]))
manifest['rendering']={'canvas':128,'sourceCanvas':512,'method':'alpha bounds; aspect preserved; optical long edge 104/112/120','icons':report}
(folder/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('Prepared',len(report),'normalised icon masks')
