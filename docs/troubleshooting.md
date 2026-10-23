# Troubleshooting

- [Diagnose](#diagnose)
- [HOME does nothing (webOS 10)](#home-does-nothing-webos-10)
- [An update fails](#an-update-fails)
- [Getting LG's Home back](#getting-lgs-home-back)

## Diagnose

`diagnose.sh` collects what is needed to look into a problem into one file:

```sh
sh /var/lib/webosbrew/rawin-launcher/diagnose.sh        # webOS 4
sh /var/lib/webosbrew/rawin-launcher-home/diagnose.sh   # webOS 10 (and --try-webos10)
sh rawin-launcher/diagnose.sh                           # from the unpacked release
```

It writes `/tmp/rawin-launcher-diagnose.txt`: the TV model, webOS and firmware
versions, what is installed, what the launcher sees (apps, HDMI inputs with
their device names, the app on screen), the HOME button binding and the
launcher's lines from the logs. No IP addresses, serial numbers or accounts.
Copy it to a computer with
`ssh root@<tv-ip> cat /tmp/rawin-launcher-diagnose.txt > diagnose.txt`
and attach it to an [issue](https://github.com/rawinek/webos-homebar/issues).

## HOME does nothing (webOS 10)

The installer binds key `773`, the HOME button of the tested Magic Remote as
Input Hook reports it. On another remote, press HOME once and read its code
from Input Hook's log (`/tmp/lginput-hook-*.log`), then change it in
`keybinds.json`.

## An update fails

The panel says which step failed (check, download or install) and OK tries
again. The installer's output is in `/tmp/rawin-launcher-update/install.log`.
The [manual update](install.md#by-hand-any-version-and-once-from-before-0100)
works for any version.

## Getting LG's Home back

- The [uninstaller](install.md#uninstall) gives LG's Home and the HOME button
  back at once.
- webOS 4: deleting `/var/lib/webosbrew/init.d/76-rawin-launcher` and
  rebooting gives LG's Home back, since the bind mounts end with a reboot.
- webOS 10: `sh /var/lib/webosbrew/rawin-launcher-home/takeover.sh restore`
  gives LG's Home back until the next boot; `takeover.sh status` shows which
  Home the TV has. If the app manager does not accept the stand-in, the script
  unmounts it and leaves LG's Home.
- If a boot hook ever crashes the start-up, the Homebrew Channel's failsafe mode
  skips all hooks on the next boot.
