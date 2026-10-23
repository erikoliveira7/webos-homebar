# Using the launcher

- [Home](#home)
- [Favourites](#favourites)
- [Apps](#apps)
- [System](#system)
- [Launcher settings](#launcher-settings)
- [Languages](#languages)

## Home

HOME on the remote opens the panel over whatever is on screen; the picture
stays visible above it. One row, from the left:

- **Favourites**: up to seven apps. With none yet, an *Add favourites* tile
  opens *Apps*.
- **HDMI 1–4**, each with the device the TV sees on it: its HDMI-CEC name, or
  the input's own name when one is set on the TV. An input with nothing
  plugged in is dimmed.
- **Apps** and **System**.

The focused item's name shows above the row, and the hints under it say what
OK and the other keys do. The clock bar in the top-right corner shows what is
on screen and the time. BACK closes the panel; from *Apps* or *System* it goes
back to Home.

LG's promotional apps (LG Channels, Sports, Alexa, …) are left out of the
launcher's lists. Nothing is uninstalled.

## Favourites

Favourites are chosen on the TV:

- In *Apps*, **hold OK** (or press YELLOW) on an app to add it, up to seven.
  A favourite is marked with a dot; holding OK on it again removes it.
- On Home, **hold OK** on a favourite to edit it: ← → move it, ▼ removes it,
  OK, BACK or ▲ finish.

A fresh install starts with none. Favourites outlast updates; an app that is
uninstalled simply drops out of them.

## Apps

All installed apps, twelve to a row, two rows on screen; the row scrolls with
the focus. An app's glow colour lights the bottom-left corner while it is
focused.

## System

| Tile | Opens |
| :--- | :--- |
| TV settings | LG's settings app |
| Launcher settings | [Launcher settings](#launcher-settings) |
| PicCap | Only when installed |
| Homebrew Channel | |
| LG Content Store | |
| Original Home | LG's own Home: always on webOS 4; on webOS 10 only when LG's Home was kept (`--keep-lg-home`, or `--try-webos10` without `--replace-lg-home`) |
| Back to the picture | Closes the panel |

The launcher's version and webOS variant are in the bottom-right corner.

## Launcher settings

OK on a setting moves it to its next value; the change applies at once.

| Setting | Values |
| :--- | :--- |
| Language | *System language* (the TV's menu language, when it is one of the [languages](#languages)), or one of them by hand |
| Theme | Default or one of ten two-colour themes, see [Themes](themes.md) |
| After holding BACK | webOS 10 only: the last input, or HDMI 1–4. Also where the TV goes when an app exits |
| Clock bar | Shown or hidden |
| App name | Whether the big name of the focused item shows on Home and in *Apps* (System and the settings always show it) |
| Updates | The installed version; OK checks, downloads and installs a new release, see [Update](install.md#update) |
| Test builds | Also offer pre-releases as updates |

## Languages

| Language | Code |
| :--- | :--- |
| English | `en` |
| Spanish (Español) | `es` |
| German (Deutsch) | `de` |
| Polish (Polski) | `pl` |
| French (Français) | `fr` |
| Italian (Italiano) | `it` |
| Portuguese (Português) | `pt` |
| Dutch (Nederlands) | `nl` |
| Czech (Čeština) | `cs` |

The launcher follows the TV's menu language when it is one of these, and falls
back to English otherwise. Corrections and new languages are welcome, see
[Development → Adding a language](development.md#adding-a-language).
