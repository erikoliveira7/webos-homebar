# Compatibility

| webOS (as the TV reports it) | Status | How the launcher is put on the TV |
| :--- | :--- | :--- |
| 4.x (webOS 4.0/4.5, 2018–2019) | Tested on 4.10 | The panel is loaded *inside* LG's Home app |
| 10.x (webOS 25, 2025) | Tested on 10.3 | A separate overlay app plus a root helper |
| 5.x – 9.x, 11.x | Untested | `install.sh` refuses; `--try-webos10` installs the webOS 10 variant with LG's Home kept |

Tested TVs:

| TV | webOS | Firmware | Variant |
| :--- | :--- | :--- | :--- |
| LG OLED55C9PLA (C9, 2019) | 4.10.2 | 05.50.00 | webOS 4 |
| LG OLED77B46LA (B4, 2024) | 10.3.1 | 33.31.68 | webOS 10 |

Other models with the same webOS major version may work. On webOS 4 the
installer patches LG's Home QML only if every piece it changes matches the
tested firmware exactly; otherwise it stops without changing anything.

## Untested webOS versions

On webOS 5–9 and 11 nothing has been tested yet. `sh install.sh --try-webos10`
installs the webOS 10 variant anyway, but leaves LG's Home in place: HOME
opens the overlay, and *System → Original Home* opens LG's. Add
`--replace-lg-home` to try the black stand-in too.

If you try it, a GitHub issue with the file from `diagnose.sh` (see
[Troubleshooting](troubleshooting.md#diagnose)) helps, whether it works or not.

How each variant works is in [How it works](how-it-works.md).
