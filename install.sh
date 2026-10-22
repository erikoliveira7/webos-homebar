#!/bin/sh
# rawin-launcher: install the variant for this TV's webOS. Run on the TV as
# root from the unpacked release: sh install.sh [options]
# Options are passed on (webOS 10: --keep-lg-home).
HERE=$(cd "$(dirname "$0")" && pwd)
major=$(sed -n 's/.*release \([0-9][0-9]*\)\..*/\1/p' /etc/starfish-release 2>/dev/null | head -n 1)
case "$major" in
    4) exec sh "$HERE/webos4/install.sh" "$@" ;;
    10) exec sh "$HERE/webos10/install.sh" "$@" ;;
    *)
        echo "rawin-launcher: webOS ${major:-unknown} is not supported (tested: webOS 4.x and 10.x; see README.md)." >&2
        exit 1
        ;;
esac
