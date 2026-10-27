"""Audit every input icon in the real panel, including geometry and visual sheets."""
import importlib.util,json,tempfile,math
from pathlib import Path
from PySide6.QtCore import Qt,QUrl,QRect,QRectF
from PySide6.QtGui import QGuiApplication,QImage,QPainter,QColor,QFont
from PySide6.QtQuick import QQuickView
ROOT=Path(__file__).resolve().parents[1]
s=importlib.util.spec_from_file_location('render',ROOT/'tools/render-panel.py');rp=importlib.util.module_from_spec(s);s.loader.exec_module(rp)
app=QGuiApplication([]);out=ROOT/'dist/icon-audit';out.mkdir(parents=True,exist_ok=True)
manifest=json.loads((ROOT/'ui/input-icons/manifest.json').read_text())
icons=[x for x in manifest['icons'] if x.get('group')!='tv'];tv=[{'id':'tv','title':'TV'}]+[x for x in manifest['icons'] if x.get('group')=='tv']
pairs={};tvshots=[];checks=0
for width,height in [(1920,1080),(1280,720)]:
 with tempfile.TemporaryDirectory() as tmp:
  d=Path(tmp);rp.panel(d);store=d/'FavouriteStore.qml';store.write_text(store.read_text().replace('rawinLauncher','visualIcons'+str(width)))
  q=(d/'Launcher.qml').read_text().rstrip()[:-1]+"""
    function named(item,name) { if(item.objectName===name)return item; for(var i=0;i<item.children.length;i++){var result=named(item.children[i],name);if(result)return result;}return null; }
    function auditGeometry() {
      var result=[];
      for(var i=0;i<sourceCells.count;i++) {
        var tile=sourceCells.itemAt(i).item,g=named(tile,i===0 ? "tvDeviceGlyph" : "deviceGlyph"),text=named(tile,"inputPrimaryBox");
        var a=tile.mapToItem(shell,0,0),b=tile.mapToItem(shell,tile.width,tile.height),ga=g.mapToItem(shell,0,0),gb=g.mapToItem(shell,g.width,g.height);
        result.push({id:tile.entry.id,icon:i===0 ? settings.tvIcon : sourceIcon(tile.entry),tile:[a.x,a.y,b.x-a.x,b.y-a.y],glyph:[ga.x,ga.y,gb.x-ga.x,gb.y-ga.y],textLeft:text ? text.mapToItem(shell,0,0).x : 0});
      }
      return JSON.stringify(result);
    }
}"""
  (d/'Launcher.qml').write_text(q);(d/'main.qml').write_text(rp.MAIN%(width,height))
  view=QQuickView();view.engine().setOfflineStoragePath(str(d/'storage'));view.setSource(QUrl.fromLocalFile(str(d/'main.qml')));assert view.status()==QQuickView.Ready,view.errors();view.show();rp.wait(200);root=view.rootObject()
  panel=next(x for x in root.childItems() if x.metaObject().className().startswith('Launcher'))
  def crop(frame,rect):
   ratio=frame.width()/width;x,y,w,h=rect
   return frame.copy(QRect(math.floor(x*ratio),math.floor(y*ratio),math.ceil(w*ratio),math.ceil(h*ratio)))
  for theme in ['default','terracotta','cobalt']:
   for start in range(0,len(icons),4):
    batch=icons[start:start+4]
    for mode in ['icon','iconHdmi','iconLabel','iconCec']:
     settings={'lang':'pl','theme':theme,'motion':False,'tv':True,'inputText':mode,'inputIcons':{f'com.webos.app.hdmi{i}':x['id'] for i,x in enumerate(batch,1)}}
     inputs=[{'id':f'com.webos.app.hdmi{i}','title':f'HDMI {i}','label':'Salon','cec':'Bardzo długa nazwa urządzenia HDMI '+str(i),'present':True} for i in range(1,len(batch)+1)]
     root.scene(json.dumps(dict(page='home',selected=0,favs=[],inputs=inputs,settings=settings)));rp.wait(110)
     geometry=json.loads(panel.auditGeometry());frame=view.grabWindow()
     assert geometry[0]['tile'][2]==geometry[0]['tile'][3]
     for item in geometry[1:]:
      gx,gy,gw,gh=item['glyph'];tx,ty,tw,th=item['tile']
      assert abs(gw-round(48*width/1920))<0.1 and abs(gh-gw)<0.1,(item,width,mode)
      assert gx>=tx and gx+gw<=tx+tw+0.1 and gy>=ty and gy+gh<=ty+th+0.1,item
      assert tw<=round(200*width/1920),item
      if mode=='icon':assert tw==round(72*width/1920) and th==round(64*width/1920),item
      else:assert item['textLeft']>=gx+gw+round(8*width/1920)-1,(item,mode)
      if width==1920 and theme=='default' and mode in ['icon','iconHdmi']:
       pairs.setdefault(item['icon'],{})[mode]=crop(frame,item['tile'])
      checks+=1
  for choice in tv:
   for mode in ['hdmiLabel','iconCec']:
    settings={'lang':'pl','theme':'default','motion':False,'tv':True,'tvIcon':choice['id'],'inputText':mode}
    root.scene(json.dumps(dict(page='home',selected=0,favs=[],inputs=rp.inputs([('Example',True)]),settings=settings)));rp.wait(130)
    item=json.loads(panel.auditGeometry())[0]
    assert item['icon']==choice['id'] and item['tile'][2]==item['tile'][3]
    if width==1920 and mode=='hdmiLabel':tvshots.append((choice,crop(view.grabWindow(),item['tile'])))
  view.close();view.deleteLater();rp.wait(30)
for group in range(math.ceil(len(icons)/20)):
 batch=icons[group*20:(group+1)*20];rows=math.ceil(len(batch)/4)
 image=QImage(1520,rows*150+50,QImage.Format_RGB32);image.fill(QColor('#111318'));p=QPainter(image);p.setRenderHint(QPainter.SmoothPixmapTransform)
 p.setPen(QColor('#bfc4ce'));p.setFont(QFont('Helvetica',14));p.drawText(20,27,'Każda para: sama ikona / ikona z tekstem. Rzeczywisty panel, bez zmiany proporcji grafik.')
 for n,entry in enumerate(batch):
  x=(n%4)*380+16;y=(n//4)*150+55
  p.setPen(QColor('#f2f3f5'));p.setFont(QFont('Helvetica',17,QFont.Bold));p.drawText(x,y+20,entry['title'])
  a=pairs[entry['id']]['icon'];b=pairs[entry['id']]['iconHdmi']
  p.drawImage(QRectF(x,y+38,a.width(),a.height()),a);p.drawImage(QRectF(x+78,y+38,b.width(),b.height()),b)
 p.end();image.save(str(out/('all-icons-'+str(group+1)+'.png')))
image=QImage(1060,185,QImage.Format_RGB32);image.fill(QColor('#111318'));p=QPainter(image)
for n,(entry,tile) in enumerate(tvshots):
 x=n*210+15;p.setPen(QColor('#f2f3f5'));p.setFont(QFont('Helvetica',13,QFont.Bold));p.drawText(QRect(x,10,195,45),Qt.AlignCenter|Qt.TextWordWrap,entry['title']);p.drawImage(x+65,75,tile)
p.end();image.save(str(out/'tv-options.png'))
(out/'audit.json').write_text(json.dumps({'inputIcons':len(icons),'tvIcons':len(tv)-1,'tvTextOption':True,'geometryChecks':checks,'resolutions':['1920x1080','1280x720'],'themes':['default','terracotta','cobalt'],'iconSlot':48,'overlap':False},indent=2)+'\n')
print('PASS',checks,'icon geometry cases; all61 icons,4 layouts,3 themes,FHD/HD;4 TV icons+text')
