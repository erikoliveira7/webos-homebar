#!/bin/sh
# rawin-launcher: install the variant for this TV's webOS. Run on the TV as
# root from the unpacked release: sh install.sh [options]
#   --try-webos10      on an untested webOS (5.x-9.x, 11.x and later) install the
#                      webOS 10 variant; LG's Home stays in place
#   --replace-lg-home  with --try-webos10: also put the black stand-in in place
#                      of LG's Home, as on webOS 10
# Other options are passed on (webOS 10: --keep-lg-home).
# RAWIN_LAUNCHER_WEBOS=<major> overrides the detected webOS version (testing).
HERE=$(cd "$(dirname "$0")" && pwd)
major=${RAWIN_LAUNCHER_WEBOS:-$(sed -n 's/.*release \([0-9][0-9]*\)\..*/\1/p' /etc/starfish-release 2>/dev/null | head -n 1)}
try=
replace=
pass=
for a in "$@"; do
    case "$a" in
        --try-webos10) try=1 ;;
        --replace-lg-home) replace=1 ;;
        *) pass="$pass $a" ;;
    esac
done
case "$major" in
    4) exec sh "$HERE/webos4/install.sh" $pass ;;
    10) exec sh "$HERE/webos10/install.sh" $pass ;;
esac
if [ -n "$try" ] && [ "${major:-0}" -ge 5 ] 2>/dev/null; then
    echo "rawin-launcher: webOS $major is untested; installing the webOS 10 variant (--try-webos10)."
    if [ -z "$replace" ]; then
        echo "rawin-launcher: LG's Home stays in place (--replace-lg-home also replaces it)."
        pass="$pass --keep-lg-home"
    fi
    exec sh "$HERE/webos10/install.sh" $pass
fi
echo "rawin-launcher: webOS ${major:-unknown} is not supported (tested: webOS 4.x and 10.x; see README.md)." >&2
[ "${major:-0}" -ge 5 ] 2>/dev/null &&
    echo "rawin-launcher: to try the webOS 10 variant anyway: sh install.sh --try-webos10" >&2
exit 1
