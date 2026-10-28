#!/bin/sh
# Change runtime ownership, not a QML preference. Keep a rollback journal before
# stopping the panel; boot recovery also uses it if power was lost mid-switch.
set -eu
umask 077
BASE=/var/lib/webosbrew/rawin-launcher-home
APP=/media/developer/apps/usr/palm/applications/org.rawin.launcher
STORE=/home/root/.local/share
HOMEAPP=/usr/palm/applications/com.webos.app.home
KEYS=/home/root/.config/lginputhook/keybinds.json
TX=$BASE/mode-switch-lock
DB=9969c85c6e1c20a73a4ac456d46e31f7
inode() { ls -di "$1" 2>/dev/null | awk '{print $1}'; }
owned() {
    case "$(node "$BASE/integration.js" owner)" in native|legacy) return 0 ;; *) return 1 ;; esac
}
foreign() {
    case "$(node "$BASE/integration.js" owner)" in lg|native|legacy) return 1 ;; *) return 0 ;; esac
}
stop_current() {
    # In companion mode even a QML Home host can belong to LG/another launcher.
    # Only stop the Home identity when our native stage actually owns its mount.
    if owned && [ "$(inode "$HOMEAPP")" = "$(inode "$BASE/native-app")" ]; then
        sh "$BASE/native-home.sh" stop
    else
        sh "$BASE/native-home.sh" stop-overlay
    fi
}
launch() {
    luna-send -n 1 luna://com.webos.applicationManager/launch "{\"id\":\"$1\"}" </dev/null | grep -q '"returnValue": *true'
}
paths() {
    printf '%s\n' "$BASE/native-home" "$BASE/additional-overlay" "$BASE/keep-lg-home" "$BASE/keys-before-native.json" "$BASE/mapper-backup.json" "$APP/Config.js"
    for id in org.rawin.launcher com.webos.app.home; do
        for suffix in sqlite ini sqlite-journal sqlite-wal sqlite-shm; do
            echo "$STORE/$id/QML/OfflineStorage/Databases/$DB.$suffix"
        done
    done
}
snapshot() {
    paths >"$TX/paths"
    i=0
    while IFS= read -r p; do
        i=$((i+1)); [ ! -f "$p" ] || cp -p "$p" "$TX/$i"
    done <"$TX/paths"
    if [ -f "$BASE/native-home" ]; then echo com.webos.app.home; else echo org.rawin.launcher; fi >"$TX/app"
    touch "$TX/ready"
}
recover() {
    if [ -f "$TX/pid" ]; then
        owner=$(cat "$TX/pid")
        if [ "$owner" != "$$" ] && [ -f "/proc/$owner/cmdline" ] &&
           { tr '\000' ' ' <"/proc/$owner/cmdline" | grep -q '/mode-switch.sh '; } &&
           kill -0 "$owner" 2>/dev/null; then
            echo 'A mode change is still running; recovery refused' >&2; return 1
        fi
    fi
    [ -f "$TX/ready" ] || { rm -rf "$TX"; return; }
    # Never remove a replacement that another launcher mounted meanwhile.
    if foreign && [ "$(cat "$TX/app")" = com.webos.app.home ]; then
        echo 'Another launcher owns Home; rollback journal retained' >&2; return 1
    fi
    mapper_recovery=0
    node "$BASE/integration.js" rollback "$TX/mapper-journal.json" || mapper_recovery=1
    if [ ! -f "$TX/runtime-restored" ]; then
    stop_current || return 1
    if owned; then sh "$BASE/takeover.sh" restore || return 1; fi
    i=0
    while IFS= read -r p; do
        i=$((i+1))
        if [ -f "$TX/$i" ]; then mkdir -p "$(dirname "$p")" && cp -p "$TX/$i" "$p" || return 1; else rm -f "$p" || return 1; fi
    done <"$TX/paths"
    if [ -f "$BASE/native-home" ]; then node "$BASE/native-stage.js" "$APP" "$BASE/native-app" || return 1; fi
    if ! foreign; then sh "$BASE/takeover.sh" apply || return 1; fi
    touch "$TX/runtime-restored" || return 1
    fi
    launch "$(cat "$TX/app")" || return 1
    [ "$mapper_recovery" = 0 ] || return 1
    echo '{"ok":false,"error":"launch_failed"}' >"$BASE/mode-result.json"
    rm -rf "$TX"
}
case "${1:-}" in
  recover) recover; exit ;;
  native) mode=native ;;
  *) echo 'usage: mode-switch.sh native|recover' >&2; exit 2 ;;
esac
expected=${2:-}
[ -z "$expected" ] || node "$BASE/integration.js" match "$expected"
[ ! -e "$TX" ] || { echo 'A mode change or recovery is already pending' >&2; exit 1; }
if foreign && [ "$mode" = native ]; then
    echo 'Another launcher owns Home; disable its Home replacement first' >&2; exit 1
fi
if [ "$mode" = native ]; then
    grep -qE 'release (10|11)\.' /etc/starfish-release || { echo 'Native Home currently supports webOS 10/11 only' >&2; exit 1; }
    sh "$BASE/native-home.sh" check-owner
fi
mkdir "$TX"
echo "$$" >"$TX/pid"
if [ -f "$BASE/native-home" ]; then echo com.webos.app.home; else echo org.rawin.launcher; fi >"$TX/app"
trap 'code=$?; trap - EXIT HUP INT TERM; if [ "$code" != 0 ]; then if [ -f "$TX/ready" ]; then recover || true; else launch "$(cat "$TX/app")" || true; rm -rf "$TX"; fi; fi; exit "$code"' EXIT
trap 'exit 1' HUP INT TERM
# Once a process is stopped, copied SQLite files are consistent, including WAL.
# Register recovery only after the complete journal has been written.
stop_current
snapshot
[ -z "$expected" ] || node "$BASE/integration.js" match "$expected"
if [ "$mode" = native ]; then
    rm -f "$BASE/keep-lg-home"
    node "$BASE/integration.js" clean native "$TX/mapper-journal.json" "$expected"
    sh "$BASE/native-home.sh" activate
    rm -f "$BASE/additional-overlay"
fi
if [ -f "$TX/result.json" ]; then cat "$TX/result.json"; else echo '{"restoreSkipped":false}'; fi
rm -rf "$TX"
# The helper keeps this result after the old QML process has gone away.
