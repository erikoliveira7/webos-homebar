#!/bin/sh
# Homebar: install the variant for this TV. Run on the TV as root from the
# unpacked release: sh install.sh [options]
#
# Two variants, and the TV gets the one it has the makings for, not the one
# its version number says (probe.sh decides; see docs/compatibility.md):
#   Home panel  the panel inside LG's own Home: where Home is a QML app and
#               the patch fits it (webOS 4 and 5 tested; webOS 3 to 8 have a QML Home)
#   overlay     an overlay app with a root helper: where Home cannot be
#               patched (webOS 10 tested; webOS 9 and 11 have that Home)
# Options:
#   --home-panel       the Home panel, or fail (no overlay instead)
#   --overlay          the overlay, or fail (needs Input Hook and node 8+)
#   --native-home      experimental direct system Home on webOS 10/11
#   --probe            only say which variant fits and why; change nothing
#   --keep-lg-home     overlay: leave LG's Home in place (no black stand-in)
#   --replace-lg-home  overlay on an untested webOS: put the black stand-in in
#                      LG Home's place anyway (on webOS 10 it always is)
#   --try-webos10      the same as --overlay (older instructions use it)
# HOMEBAR_WEBOS=<version> overrides the detected webOS version (testing).
HERE=$(cd "$(dirname "$0")" && pwd)
PROBE=$HERE/probe.sh

say() { echo "rawin-launcher: $*"; }
fail() { echo "rawin-launcher: $*" >&2; exit 1; }
detail() { printf '%s\n' "$1" | sed 's/^rawin-launcher: //; s/^/rawin-launcher:   /'; }

version=${HOMEBAR_WEBOS:-${RAWIN_LAUNCHER_WEBOS:-$(sed -n 's/.*release \([0-9][0-9.]*\).*/\1/p' /etc/starfish-release 2>/dev/null | head -n 1)}}
major=${version%%.*}
force=
probe=
keep=
replace=
native=
explicit=
pass=
for a in "$@"; do
    case "$a" in
        --home-panel) force=panel ;;
        --overlay|--try-webos10) force=overlay ;;
        --native-home) native=1; explicit=1; force=overlay; pass="$pass --native-home" ;;
        --additional-overlay) fail "additional overlay and runtime mode switching are not included in this build" ;;
        --probe) probe=1 ;;
        --keep-lg-home) keep=1 ;;
        --replace-lg-home) replace=1 ;;
        *) pass="$pass $a" ;;
    esac
done

# LG's name for it: from version 7 on, the year (webOS 22 is 7.x, webOS 25
# is 10.x); people often know only that one.
name=
case "$major" in
    ''|*[!0-9]*|[1-6]) ;;
    *) name=", which LG calls webOS $((major + 15))" ;;
esac
case "$major" in
    4|5|6|10) tested="tested on $major.x" ;;
    *) tested="untested; 4.x, 5.x, 6.x and 10.x are the tested ones" ;;
esac
say "webOS ${version:-unknown}$name ($tested)"

if [ -n "$probe" ]; then
    if [ -n "$native" ]; then sh "$PROBE" native-home
    else sh "$PROBE"; fi
    say "probe only; nothing was changed"
    exit 0
fi

if [ -d /var/lib/webosbrew/rawin-launcher-home/mode-switch-lock ]; then
    sh /var/lib/webosbrew/rawin-launcher-home/mode-switch.sh recover || fail "mode recovery failed"
fi
# The ribbon Home remains unchanged. Supported newer TVs use system HOME for
# both fresh installs and updates, with migration checks before any installation.
if [ -f /var/lib/webosbrew/rawin-launcher-home/additional-overlay ]; then
    fail "this experimental additional-overlay install belongs to the mode-switching branch; restore its previous configuration before installing this build"
fi
# Whoever chose to keep LG's Home (--keep-lg-home, or an install made with it)
# stays on the compatibility overlay: system HOME replaces that Home.
if [ "$force" != panel ] && [ -z "$keep" ] && [ ! -f /var/lib/webosbrew/rawin-launcher-home/keep-lg-home ]; then
    case "$major" in
        10|11) force=overlay; native=1 ;;
    esac
fi
if [ -n "$native" ]; then
    [ -z "$keep" ] || fail "system HOME cannot be combined with --keep-lg-home"
    # The panel's updater always passes --replace-lg-home on webOS 10: it only
    # means "keep the setup", so it is dropped when system HOME is picked for
    # the TV; asked for with --native-home it is a conflict.
    [ -z "$explicit" ] || [ -z "$replace" ] || fail "system HOME cannot be combined with replace-lg-home"
    replace=
    sh "$PROBE" native-home || fail "system HOME checks failed; nothing installed"
    pass="$pass --native-home"
elif [ -f /var/lib/webosbrew/rawin-launcher-home/native-home ]; then
    fail "an existing native Home requires a supported webOS; inspect Diagnose before updating"
fi
if [ -z "$force" ] && [ -f /var/lib/webosbrew/rawin-launcher-home/VERSION ]; then force=overlay; fi
if [ -z "$force" ] && [ -f /var/lib/webosbrew/rawin-launcher/VERSION ]; then force=panel; fi
variant=$force
if [ -z "$variant" ]; then
    if panel_why=$(sh "$PROBE" panel 2>&1); then variant=panel
    elif overlay_why=$(sh "$PROBE" overlay 2>&1); then variant=overlay
    else
        { say "installation blocked; see the requirements below"
          say "Home panel: does not fit"; detail "$panel_why"
          say "overlay: requirements not met"; detail "$overlay_why"; } >&2
        fail "see docs/compatibility.md; sh install.sh --probe repeats this check"
    fi
fi

case "$variant" in
    panel)
        say "installing the Home panel (the panel inside LG's Home)"
        exec sh "$HERE/webos4/install.sh" $pass
        ;;
    overlay)
        # LG's Home is replaced by the black stand-in on webOS 10, where that is
        # tested; elsewhere it stays unless asked otherwise.
        if [ -n "$keep" ]; then pass="$pass --keep-lg-home"
        elif [ "$major" != 10 ] && [ -z "$replace$native" ]; then
            say "LG's Home stays in place on this webOS (--replace-lg-home puts the black stand-in there too)"
            pass="$pass --keep-lg-home"
        fi
        say "installing the overlay (an overlay app with a root helper)"
        exec sh "$HERE/webos10/install.sh" $pass
        ;;
esac
