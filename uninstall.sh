#!/bin/sh
# rawin-launcher: remove whichever variant is installed. Run on the TV as root.
found=
for u in /var/lib/webosbrew/rawin-launcher/uninstall.sh /var/lib/webosbrew/rawin-launcher-home/uninstall.sh; do
    if [ -f "$u" ]; then sh "$u"; found=1; fi
done
[ -n "$found" ] || echo "rawin-launcher: not installed."
