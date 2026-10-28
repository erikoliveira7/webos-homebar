#!/bin/sh
# rawin-launcher (webOS 10): put a black stand-in in LG Home's place, or
# give LG Home back. Usage: home-takeover.sh apply|restore|status
#
# The stand-in (app/, a black web page under the id com.webos.app.home) is
# bind-mounted over /usr/palm/applications/com.webos.app.home; the read-only
# rootfs is not touched and the mount ends with a reboot (the boot hook applies
# it again). sam reads the app again after a block and release of the one app
# (the same two calls Glasshouse uses on webOS 10), then LG's Flutter Home is
# stopped. From then on everything that opens Home opens the black page and
# the helper goes back to the last input, so LG's launcher never shows.
# No check for webosbrew_failsafe: the Homebrew Channel sets that flag during
# every normal start while it runs the init.d hooks, and in real failsafe mode
# it runs no hooks at all.
HOMEAPP=/usr/palm/applications/com.webos.app.home
BASE=/var/lib/webosbrew/rawin-launcher-home
STAGE=$BASE/app
HOME_TYPE=web
if [ -f "$BASE/native-home" ]; then STAGE=$BASE/native-app; HOME_TYPE=qml; fi
TAG=rawin-launcher
# The system log and, with the seconds since boot, the launcher's boot log
# (cleared with /tmp at every boot; diagnose.sh shows it).
log() { logger -t $TAG "$1"; echo "$(cut -d' ' -f1 /proc/uptime)s $1" >>/tmp/rawin-launcher-boot.log; }

inode() { ls -di "$1" 2>/dev/null | awk '{print $1}'; }
mounted() {
  [ -n "$(inode "$STAGE")" ] && [ "$(inode "$HOMEAPP")" = "$(inode "$STAGE")" ] || return 1
  # A later nested/binary mount can replace Home while its directory stays ours.
  [ ! -f "$BASE/integration.js" ] || case "$(node "$BASE/integration.js" owner)" in native|legacy) return 0 ;; *) return 1 ;; esac
}

luna() { luna-send -n 1 "luna://com.webos.applicationManager/$1" "$2" 2>/dev/null; }
ok() { grep -q '"returnValue": *true'; }

# sam reads one system app again after it is blocked and released; the release
# is sent whatever the block answered, so Home is never left blocked.
reread() {
  luna blockSystemApp '{"id":"com.webos.app.home"}' >/dev/null
  for _ in 1 2 3; do
    luna releaseBlockSystemApp '{"id":"com.webos.app.home"}' | ok && return 0
    sleep 1
  done
  return 1
}

# Whether sam reports Home's type as $1 within 20 s.
home_type_is() {
  for _ in $(seq 20); do
    luna getAppInfo '{"id":"com.webos.app.home"}' | grep -q "\"type\": *\"$1\"" && return 0
    sleep 1
  done
  return 1
}

# LG's own Home process: flutter-client running the Home id (webOS 10), or
# the QML Home's own process on a webOS where Home is a QML app and the
# overlay was chosen anyway. The stand-in itself runs in the web app manager.
lg_home_pids() {
  for cmd in /proc/[0-9]*/cmdline; do
    { tr '\0' ' ' < "$cmd"; } 2>/dev/null | grep -q '^/usr/bin/flutter-client .*-i com\.webos\.app\.home ' || continue
    pid=${cmd#/proc/}
    echo "${pid%/cmdline}"
  done
  pidof com.webos.app.home 2>/dev/null | tr ' ' '\n'
}

case "$1" in
  apply)
    [ -f "$STAGE/appinfo.json" ] || exit 0
    if [ -f "$BASE/native-home" ]; then node "$BASE/integration.js" check || exit 1; fi
    # Installed with --keep-lg-home: LG's Home stays.
    [ -e "$BASE/keep-lg-home" ] && exit 0
    if grep -q '"enabled"[[:space:]]*:[[:space:]]*true' /var/lib/tvweb/home.json 2>/dev/null; then
      log 'Glasshouse Home is on: LG Home left to it'
      exit 0
    fi
    if [ -f "$BASE/integration.js" ]; then
      case "$(node "$BASE/integration.js" owner)" in lg|native|legacy) ;; *) log 'another or unknown Home owner; refusing takeover'; exit 1 ;; esac
    fi
    # sam answers only once it is up (at boot this hook runs early).
    for _ in $(seq 60); do luna getAppInfo '{"id":"com.webos.app.home"}' | ok && break; sleep 2; done
    log 'stand-in: app manager up'
    # Never stack a takeover over an unrelated launcher or a different mode.
    if ! mounted && grep -qF " $HOMEAPP " /proc/mounts; then
      log 'another Home mount is present; refusing takeover'
      exit 1
    fi
    mounted || mount --bind "$STAGE" "$HOMEAPP" || { log 'mount failed: LG Home kept'; exit 1; }
    if reread && home_type_is "$HOME_TYPE"; then
      for pid in $(lg_home_pids); do kill "$pid" 2>/dev/null; done
      log "$HOME_TYPE Homebar in LG Home place"
    else
      umount "$HOMEAPP" 2>/dev/null
      reread
      log 'sam did not take the stand-in: LG Home kept'
      exit 1
    fi
    ;;
  restore)
    # Never close or reread a Home instance owned by a different launcher.
    mounted || exit 0
    # SAM's preload manager can respawn the QML host between stopping it and
    # unmounting its files. Block Home first, then stop again under that block.
    # Releasing below happens only after the original manifest is visible.
    luna blockSystemApp '{"id":"com.webos.app.home"}' >/dev/null
    [ ! -f "$BASE/native-home" ] || sh "$BASE/native-home.sh" stop
    if mounted && ! umount "$HOMEAPP"; then reread; exit 1; fi
    reread || exit 1
    home_type_is flutter
    # The black page may still run in the web app manager; sam then takes it for
    # the running Home and every launch of Home waits on it. Close it there.
    luna-send -n 1 luna://com.webos.service.webappmanager/killApp '{"appId":"com.webos.app.home"}' </dev/null >/dev/null 2>&1
    luna closeByAppId '{"id":"com.webos.app.home"}' >/dev/null
    log 'LG Home given back'
    ;;
  status)
    if mounted; then echo "stand-in mounted"; else echo "LG Home"; fi
    luna getAppInfo '{"id":"com.webos.app.home"}' | grep -o '"type": *"[a-z]*"'
    echo "LG Home pids: $(lg_home_pids | tr '\n' ' ')"
    ;;
  *)
    echo "usage: $0 apply|restore|status" >&2
    exit 2
    ;;
esac
