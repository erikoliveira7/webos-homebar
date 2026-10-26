#!/usr/bin/env python3
"""Open an interactive desktop Homebar simulator.

It uses the same desktop stubs as render-panel.py: keys, pointer and settings
work locally, while TV services, launching apps and restarting Homebar are
harmless no-ops. Close its window to stop it.
"""
import argparse
import importlib.util
import json
import sys
import tempfile
from pathlib import Path

from PySide6.QtCore import QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQuick import QQuickView

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("render_panel", ROOT / "tools" / "render-panel.py")
rp = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rp)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--size", default="1920x1080", help="simulated TV resolution, default: 1920x1080")
    parser.add_argument("--page", choices=("home", "apps", "system", "settings"), default="home",
                        help="page to open first, default: home")
    parser.add_argument("--selected", type=int, default=0, help="initial selected item, default: 0")
    args = parser.parse_args()
    w, h = (int(v) for v in args.size.split("x"))
    app = QGuiApplication(sys.argv)
    with tempfile.TemporaryDirectory() as tmp:
        app_dir = Path(tmp)
        rp.panel(app_dir)
        # The renderer supplies static scenes; the interactive host must also
        # mark services ready and handle the panel's requests to hide itself.
        main = rp.MAIN.replace('foreground: true; nowTitle:', 'foreground: true; ready: true; nowTitle:')
        main = main.replace('Item {\n', 'Item {\n    id: simulatorHost\n', 1)
        main = main.rstrip()[:-1] + """
    function hidePanel() { shell.foreground = false; shell.visible = false; simulatorHost.forceActiveFocus(); }
    function showPanel() { shell.visible = true; shell.foreground = true; shell.forceActiveFocus(); }
    Connections {
        target: shell
        function onCloseRequested() { hidePanel(); }
        function onTimeoutRequested() { hidePanel(); }
    }
    Keys.onPressed: { if (event.key === Qt.Key_F2) { showPanel(); event.accepted = true; } }
}
"""
        (app_dir / "main.qml").write_text(main % (w, h))
        view = QQuickView()
        view.setTitle("Homebar simulator — F2: HOME")
        view.setSource(QUrl.fromLocalFile(str(app_dir / "main.qml")))
        if view.status() != QQuickView.Ready:
            raise SystemExit("\n".join(e.toString() for e in view.errors()))
        view.show()
        view.requestActivate()
        root = view.rootObject()
        root.scene(json.dumps({
            "favs": [a[0] for a in rp.APPS[:7]],
            "inputs": rp.inputs(rp.INPUTS),
            "settings": {"tv": True, "weather": True},
            "weather": {"ok": True, "temp": 18, "apparent": 23, "code": 2, "day": True},
            "page": args.page, "selected": args.selected
        }))
        root.focusPanel()
        sys.exit(app.exec())


if __name__ == "__main__":
    main()
