#!/bin/sh
# rawin-launcher installer for webOS 4 (LG Home QML panel). Run on the TV as
# root, from the unpacked release: sh webos4/install.sh (or sh install.sh).
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
UI=$HERE/../ui
BASE=/var/lib/webosbrew/rawin-launcher
HOOK=/var/lib/webosbrew/init.d/76-rawin-launcher
ROOT=/usr/palm/applications/com.webos.app.home/qml
MAIN=$ROOT/main.qml
CTRL=$ROOT/Controllers/UIController.qml

say() { echo "rawin-launcher: $*"; }
fail() { echo "rawin-launcher: $*" >&2; exit 1; }

[ "$(id -u)" = 0 ] || fail "run this as root on the TV"
[ -d /var/lib/webosbrew ] || fail "the Homebrew Channel (root) is not set up on this TV"
command -v node >/dev/null || fail "node is missing on this TV"
[ -f "$MAIN" ] && [ -f "$CTRL" ] || fail "LG Home QML not found: this is not a webOS 4 Home"

# LG's original files: from the firmware, or from the previous install while
# its mounts hide them.
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
if grep -qF " $MAIN " /proc/mounts || grep -qF " $CTRL " /proc/mounts; then
    [ -f "$BASE/main.original.qml" ] && [ -f "$BASE/UIController.original.qml" ] || fail "LG Home is already replaced by something else; restore it first"
    cp "$BASE/main.original.qml" "$BASE/UIController.original.qml" "$TMP/"
else
    cp "$MAIN" "$TMP/main.original.qml"
    cp "$CTRL" "$TMP/UIController.original.qml"
fi
node "$HERE/patch-home.js" "$TMP" || fail "LG Home was not changed"

say "installing to $BASE"
for f in "$MAIN" "$CTRL"; do
    if grep -qF " $f " /proc/mounts; then umount "$f"; fi
done
# A fresh copy of the panel; files of older versions go.
rm -rf "$BASE/current" "$BASE/restore.sh"
mkdir -p "$BASE/current/fonts"
cp "$TMP/main.original.qml" "$TMP/UIController.original.qml" "$TMP/main.qml" "$TMP/UIController.qml" "$BASE/"
cp "$UI/Launcher.qml" "$UI/FavouriteStore.qml" "$UI/Strings.js" "$HERE/Config.js" "$BASE/current/"
cp "$UI"/fonts/* "$BASE/current/fonts/"
cp "$HERE/apply.sh" "$HERE/uninstall.sh" "$HERE/../update.sh" "$HERE/../VERSION" "$BASE/"
chmod 755 "$BASE/apply.sh" "$BASE/uninstall.sh" "$BASE/update.sh"
mkdir -p /var/lib/webosbrew/init.d
ln -sf "$BASE/apply.sh" "$HOOK"
sh "$BASE/apply.sh"
say "done. Press HOME on the remote."
say "uninstall: sh $BASE/uninstall.sh"
