// rawin-launcher for webOS 4: build patched copies of LG Home's main.qml and
// Controllers/UIController.qml from the firmware originals.
//
// main.qml gets a Loader for the launcher panel (current/Launcher.qml) on top
// of LG's UI, which stays in the same process, so LG's window, lifecycle and
// HOME handling are kept. LG's own ribbon is shown only when the panel asks
// for it ("Original Home"); BLUE comes back. Every replacement must match
// exactly once, so a firmware with a different Home is refused, not guessed at.
//
// Usage: node patch-home.js <dir>   (reads <dir>/main.original.qml and
// <dir>/UIController.original.qml, writes <dir>/main.qml and <dir>/UIController.qml)
// Plain ES5 for old node versions.
'use strict';
var fs = require('fs');
var path = require('path');

var dir = process.argv[2];
if (!dir) {
  console.error('usage: node patch-home.js <dir>');
  process.exit(2);
}

var INJECTION = [
  '',
  '    // rawin-launcher: the panel on top of LG Home, in LG\'s own process.',
  '    property bool cleanHomeStock: false',
  '    Loader {',
  '        id: cleanHomeLoader',
  '        z: 500',
  '        anchors.fill: parent',
  '        source: "file:///var/lib/webosbrew/rawin-launcher/current/Launcher.qml"',
  '        visible: !rootWindow.cleanHomeStock',
  '        onStatusChanged: {',
  '            if (status === Loader.Error) rootWindow.cleanHomeStock = true;',
  '        }',
  '        onLoaded: {',
  '            item.hostWindow = rootWindow;',
  '            item.ready = Qt.binding(function() { return systemProperties.isAppReadyToUse; });',
  '            item.foreground = Qt.binding(function() { return systemProperties.isAppForeground && !rootWindow.cleanHomeStock; });',
  '        }',
  '    }',
  '    Connections {',
  '        target: cleanHomeLoader.item',
  '        onStockRequested: { rootWindow.cleanHomeStock = true; uiController.currentMode="main"; uiController.startApp(); uiController.forceActiveFocus(); }',
  '        onCloseRequested: { interfaces.application.closeApp(); }',
  '    }',
  '    Connections {',
  '        target: systemProperties',
  '        onIsAppForegroundChanged: {',
  '            if (systemProperties.isAppForeground) rootWindow.cleanHomeStock=false;',
  '        }',
  '    }',
  '    Rectangle {',
  '        z: 600',
  '        visible: rootWindow.cleanHomeStock && systemProperties.isAppForeground',
  '        anchors.right: parent.right; anchors.rightMargin: 60; y: 45',
  '        width: 450; height: 58; radius: 29; color: "#152d32"',
  '        Text { anchors.centerIn: parent; text: "Blue · back to rawin-launcher"; color: "#8be2cb"; font.pixelSize: 22 }',
  '        MouseArea { anchors.fill: parent; onClicked: { rootWindow.cleanHomeStock=false; cleanHomeLoader.item.forceActiveFocus(); } }',
  '    }',
  ''
].join('\n');

function replaceOnce(text, oldText, newText, what) {
  var at = text.indexOf(oldText);
  if (at < 0 || text.indexOf(oldText, at + oldText.length) >= 0) {
    console.error('rawin-launcher: LG Home differs from the tested firmware (' + what + '); nothing changed');
    process.exit(1);
  }
  return text.slice(0, at) + newText + text.slice(at + oldText.length);
}

var main = fs.readFileSync(path.join(dir, 'main.original.qml'), 'utf8');
if (main.indexOf('cleanHomeLoader') >= 0) {
  console.error('rawin-launcher: main.original.qml is already patched; restore the firmware file first');
  process.exit(1);
}
main = replaceOnce(main, 'import QtQuick 2.6', 'import QtQuick 2.6\nimport WebOS.Global 1.0', 'import');
main = replaceOnce(main, '    //UI Controller', INJECTION + '\n    //UI Controller', 'UI Controller anchor');
main = replaceOnce(main, '        id: uiController\n', [
  '        id: uiController',
  '        visible: rootWindow.cleanHomeStock || cleanHomeLoader.status !== Loader.Ready',
  '        enabled: visible',
  '        focus: rootWindow.cleanHomeStock',
  ''
].join('\n'), 'uiController');
main = replaceOnce(main, '    function focusIn() {', '    function focusIn() {\n        rootWindow.cleanHomeStock = false;', 'focusIn');
main = replaceOnce(main, '    function keyPressEvent(keyCode) {', [
  '    function keyPressEvent(keyCode) {',
  '        if (rootWindow.cleanHomeStock && keyCode === WebOS.Key_webOS_Blue) {',
  '            rootWindow.cleanHomeStock=false;',
  '            if (cleanHomeLoader.item) cleanHomeLoader.item.forceActiveFocus();',
  '            return;',
  '        }'
].join('\n'), 'keyPressEvent');

// LG's controller: hide, voice and the "Home shown" path only act while LG's
// own ribbon is the visible UI.
var ctrl = fs.readFileSync(path.join(dir, 'UIController.original.qml'), 'utf8');
ctrl = replaceOnce(ctrl, 'if(root.isHiddenMode && state !== "hidden")', 'if(root.isHiddenMode && state !== "hidden" && rootWindow.cleanHomeStock)', 'hidden mode');
ctrl = replaceOnce(ctrl, 'interfaces.voice.register();', 'if(rootWindow.cleanHomeStock) interfaces.voice.register();', 'voice');
ctrl = replaceOnce(ctrl, 'if(homeShown) {', 'if(homeShown && rootWindow.cleanHomeStock) {', 'homeShown');

fs.writeFileSync(path.join(dir, 'main.qml'), main);
fs.writeFileSync(path.join(dir, 'UIController.qml'), ctrl);
console.log('rawin-launcher: LG Home patched');
