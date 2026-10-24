# Compatibility

- [Which variant a TV gets](#which-variant-a-tv-gets)
- [webOS versions](#webos-versions)
- [Screen sizes](#screen-sizes)
- [Tested TVs](#tested-tvs)
- [Trying an untested webOS](#trying-an-untested-webos)

## Which variant a TV gets

Homebar is one panel (`ui/Launcher.qml`) put on the screen in one of two
ways. The installer picks by what the TV has, not by its version number:

| Variant | When | How |
| :--- | :--- | :--- |
| **Home panel** | LG's Home is a QML app and the patch fits it | The panel is loaded *inside* LG's Home; LG's HOME handling, window and lifecycle are kept |
| **Overlay** | Otherwise, with the Homebrew Channel, the *Input Hook* app and node 8 or newer | A separate overlay app plus a root helper; Input Hook sends HOME to it |

`sh install.sh --probe` says which one fits and why, and changes nothing;
`--home-panel` and `--overlay` force one. The same check is `probe.sh`,
next to `install.sh` in the release and next to `diagnose.sh` once
installed; `diagnose.sh` runs it.

The Home panel's patch is made of pieces. The ones the panel cannot do
without must match (the root element, LG's UI controller, Home's foreground
state, `isAppForeground`, declared in Home's `SystemProperties.qml`); the
rest (focus coming back, the BLUE key, LG's hidden mode, voice) go in where
they match and are reported where they do not, so a Home that differs a
little still gets the panel. "QML app" here means a Home whose UI is QML
under `/usr/palm/applications/com.webos.app.home/qml/`; the app manager
reports webOS 4's as `native`, a program that loads that QML.

## webOS versions

LG gives webOS two numbers, and they are easy to mix up. The TV itself, the
installer and `diagnose.sh` report the system's own version (10.3.1); LG's
site, the box and the TV's spec sheets use a name, which since 2022 is a
year: webOS 22 is version 7, webOS 25 is version 10. The model year alone
does not say which one a TV has either: with LG's *webOS Re:New* updates an
older TV can get a newer webOS (an LG UR78 from 2023 updated to webOS 25
reports 10.3.2). This page goes by the version the TV reports, with LG's
name next to it.

| The TV reports | LG calls it | First on (model year) | LG Home | Variant the installer picks | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 1.x – 2.x | webOS 1.0 – 2.0 | 2014–2015 | Web app | — (no variant fits: no QML Home, node 0.10) | Not supported |
| 3.x | webOS 3.0, 3.5 | 2016–2017 | QML | Home panel, if the patch fits | Untested |
| 4.x | webOS 4.0, 4.5 | 2018–2019 | QML | Home panel | **Tested on 4.10** (webOS 4.5) |
| 5.x | webOS 5.0 | 2020 | QML, the same kind of ribbon as 4.x | Home panel if the patch fits, else overlay | Untested |
| 6.x | webOS 6.0 | 2021 | QML, a new full-screen Home | Overlay, LG's Home kept unless `--replace-lg-home` | **Tested on 6.3 and 6.5** (LG C1 and UP78, by users) |
| 7.x | webOS 22 | 2022 | QML, as far as known; the full-screen Home | Most likely the overlay, as on 6.x | Untested |
| 8.x | webOS 23 | 2023 | QML, as far as known; the full-screen Home | Most likely the overlay, as on 6.x | Untested |
| 9.x | webOS 24 | 2024 | Flutter, like 10.x | Overlay, LG's Home kept unless `--replace-lg-home` | Untested |
| 10.x | webOS 25 | 2025 | Flutter | Overlay, LG's Home replaced by the black stand-in | **Tested on 10.3** |
| 11.x | webOS 26 | 2026 | Flutter, like 10.x | Overlay, LG's Home kept unless `--replace-lg-home` | Untested |

What the untested rows rest on: LG's Home was a QML app
(`/usr/palm/applications/com.webos.app.home/qml`) from webOS 3 to the last
QML Home, and the patch only needs the few things every one of them has
(see above). The patch was written against the ribbon Home of webOS 4; the
full-screen Home that came with webOS 6 is a different app, so there the
patch does not fit and the installer goes on with the overlay, with LG's
Home left in place unless `--replace-lg-home` (so it went on an LG C1 with
webOS 6.3.2). The overlay needs what the Homebrew Channel gives any rooted
TV, Input Hook, and a node new enough for the helper: webOS 3 and 4 ship
node 0.12, webOS 5 node 8, webOS 6 and later node 12 or newer. The black
stand-in for LG's Home (a block and release of the one app, as
[Glasshouse](https://github.com/rorygallagher2024/glasshouse) does) is
tested on webOS 10 only, which is why elsewhere the overlay leaves LG's Home
in place by default.

Other models with the tested webOS versions may work. If the patch does not
fit a webOS 4 TV's Home (another firmware), the installer says so and stops
without changing anything.

Some webOS 4 TVs (the 2019 UM series, for one) have two Homes and a *Home
screen* setting to choose between them: *Basic*, LG's ribbon
(`com.webos.app.home`), and *New*, a full-screen one
(`com.webos.app.fullhome`). The panel lives in the Basic one, so on these
TVs the Home screen has to be set to *Basic*; with *New*, HOME opens LG's
New Home and the panel never shows. `--probe`, the installer and
`diagnose.sh` say when a TV has the New Home, and whether it is the one
running.

## Screen sizes

The panel lays itself out for the screen it gets. LG's UI runs at 1920×1080
on FHD and UHD TVs (the TV scales it to the panel) and at 1280×720 on HD
ones; the panel scales every length with the screen, keeps the rail inside
the right margin whatever the TV's inputs are called, and fills a wider
screen with more columns in *Apps*. The overlay takes the screen's size
when it is smaller than FHD and stays at 1920×1080 otherwise; the Home panel
fills LG's window. `tools/render-panel.py` draws the panel at any size on a
computer, see [Development](development.md#checking-the-layout).

The TV's inputs are read from the TV: a set with two HDMI ports shows two
pills, one with DisplayPort or USB-C shows those too.

## Tested TVs

| TV | webOS (LG's name) | Firmware | Variant | Last tested with |
| :--- | :--- | :--- | :--- | :--- |
| LG OLED55C9PLA (C9, 2019) | 4.10.2 (webOS 4.5) | 05.50.00 | Home panel | 0.15.2 |
| LG OLED77B46LA (B4, 2024) | 10.3.1 (webOS 25) | 33.31.68 | Overlay | 0.15.0 |
| LG 43UR78006LK (UR78, 2023, updated to webOS 25) | 10.3.2 (webOS 25) | 33.31.75 | Overlay, LG's Home kept (`--keep-lg-home`) | 0.14.0, by a user |
| LG 43UM7100PLB (UM71, 2019) | 4.10.2 (webOS 4.5) | 05.40.97 | Home panel, with the TV's Home screen on *Basic* | 0.14.1, by a user |
| LG OLED55C16LA (C1, 2021) | 6.3.2 (webOS 6.0) | 03.34.80 | Overlay, LG's Home kept | 0.14.0, by a user |
| LG 43UP78006LB (UP78, 2021) | 6.5.3 (webOS 6.0) | 03.53.45 | Overlay, LG's Home kept | 0.15.1, by a user |

## Trying an untested webOS

`sh install.sh` on an untested webOS says so and goes on with the variant
that fits. `--probe` first shows what it would do. If it does not work, or
not well, a GitHub issue with the file from `diagnose.sh` (see
[Troubleshooting](troubleshooting.md#diagnose)) helps, whether it worked or
not. What can go wrong and how to get LG's Home back is in
[Troubleshooting → An untested webOS](troubleshooting.md#an-untested-webos).

How each variant works is in [How it works](how-it-works.md).
