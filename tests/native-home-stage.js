// Staging must retain the UI and the normal package identity while giving
// only the mounted Home its native lifecycle and Config flag.
const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const stage = require('../webos10/native-stage');
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'homebar-native-'));
try {
    const app = path.join(tmp, 'app'), target = path.join(tmp, 'home');
    fs.mkdirSync(app);
    fs.writeFileSync(path.join(app, 'appinfo.json'), JSON.stringify({id:'org.rawin.launcher',type:'qml',main:'main.qml'}));
    fs.writeFileSync(path.join(app, 'Config.js'), 'var version = "test";\nvar exitTarget = true;\n');
    ['main.qml','Panel.qml','FavouriteStore.qml','Strings.js','Themes.js','About.js','DeviceIcons.js','DeviceIcon.qml','input-icons','fonts','icon.png'].forEach(n => fs.writeFileSync(path.join(app,n), n));
    stage(app,target);
    stage(app,target); // ordinary updates must replace links safely
    ['DeviceIcons.js','DeviceIcon.qml','input-icons'].forEach(n => assert.strictEqual(fs.readFileSync(path.join(target,n),'utf8'),n));
    const info = JSON.parse(fs.readFileSync(path.join(target,'appinfo.json')));
    assert.strictEqual(info.id,'com.webos.app.home');
    assert.strictEqual(info.nativeLifeCycleInterfaceVersion,2);
    assert.strictEqual(info.type,'qml');
    assert.strictEqual(info.defaultWindowType,'overlay');
    assert.strictEqual(info.closeOnBackground,false);
    assert(fs.readFileSync(path.join(target,'Config.js'),'utf8').includes('var exitTarget = true;'));
    assert.strictEqual(fs.readlinkSync(path.join(target,'Panel.qml')),path.join(app,'Panel.qml'));
    assert(fs.readFileSync(path.join(target,'Config.js'),'utf8').includes('var nativeHome = true;'));
    assert(!fs.readFileSync(path.join(app,'Config.js'),'utf8').includes('nativeHome'));
    assert.strictEqual(JSON.parse(fs.readFileSync(path.join(app,'appinfo.json'))).id,'org.rawin.launcher');
    console.log('PASS native Home stage, update, overlay type and original package preservation');
} finally { fs.rmSync(tmp,{recursive:true,force:true}); }
