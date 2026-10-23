// Homebar for webOS 10: the shared panel (Panel.qml, generated from
// ui/Launcher.qml by tools/build.py) in a developer QML overlay window run by
// qml-runner. HOME relaunches the app; qml-runner resets the "params" context
// property, which shows the panel again. BACK hides the window but keeps the
// process, so the next HOME is a show, not a start.
import QtQuick 2.4
import Eos.Window 0.1

WebOSWindow {
    id: win
    windowType: "_WEBOS_WINDOW_TYPE_OVERLAY"
    width: 1920; height: 1080
    visible: true
    color: "transparent"
    appId: "org.rawin.launcher"
    title: "Homebar"

    property var launchParams: typeof params !== "undefined" ? params : null
    onLaunchParamsChanged: show()

    function show() {
        hideTimer.stop();
        win.visible = true;
        home.foreground = true;
        home.forceActiveFocus();
        home.loadInputs();
    }
    function hide() {
        home.foreground = false;   // runs the panel's 180 ms fade-out
        hideTimer.restart();
    }
    Timer { id: hideTimer; interval: 200; onTriggered: win.visible = false }

    Panel {
        id: home
        anchors.fill: parent
        foreground: true
        onCloseRequested: win.hide()
        // Original LG Home: SAM opens it as a card; we step aside.
        onStockRequested: http("/launch?id=com.webos.app.home", function() { win.hide(); })
        Component.onCompleted: { home.ready = true; home.loadInputs(); home.forceActiveFocus(); }
    }
}
