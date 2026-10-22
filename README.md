# rawin-launcher

![rawin-launcher over a YouTube video: favourites, HDMI inputs, Apps and System](docs/screenshots/home.jpg)

A minimal home screen for rooted LG webOS TVs. HOME opens a bottom panel over
whatever is on screen: up to seven favourite apps, the HDMI inputs with the
device the TV sees on each (HDMI-CEC name), all installed apps, and a System
page. The picture stays visible above it.

- Favourites are chosen on the TV: hold **OK** on an app in *Apps* to add it
  (up to seven), hold **OK** on a favourite to move or remove it. A fresh install
  starts with none and shows an *Add favourites* tile that opens *Apps*.
- **System → Launcher settings**: language (system language by default;
  English, Spanish, German, Polish), what to show after holding BACK
  (webOS 10), the clock bar, whether the big name of the focused app shows,
  and **Updates**: the launcher updates itself from this repository's releases.
- LG's promotional apps (LG Channels, Sports, Alexa, …) are hidden from the
  launcher's lists. Nothing is uninstalled.
- **webOS 10 only:** LG's own Home never appears. A black stand-in takes its
  place, and the TV goes back to the last input (or a chosen HDMI) when an app
  exits or BACK is held.

## Preview

<img src="docs/screenshots/demo.gif" width="100%" alt="Demo: HOME opens the launcher, System, Launcher settings: languages, clock bar, app name">

## Compatibility

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

On webOS 5–9 and 11 nothing has been tested yet. `sh install.sh --try-webos10`
installs the webOS 10 variant anyway, but leaves LG's Home in place: HOME
opens the overlay, and *System → Original Home* opens LG's. Add
`--replace-lg-home` to try the black stand-in too. If you try it, a GitHub
issue with the file from `diagnose.sh` (see [Troubleshooting](#troubleshooting))
helps, whether it works or not.

### How it works on webOS 4

LG's Home (`com.webos.app.home`) is a QML app. `webos4/patch-home.js` makes a
copy of its `main.qml` with a `Loader` for the launcher panel on top of LG's UI,
and of `Controllers/UIController.qml` so LG's ribbon stays out of the way. A
Homebrew boot hook bind-mounts the two files over the firmware ones, hides
Home's CRIU snapshot (which would otherwise restore the original QML from
memory) and restarts only the Home process. LG's window, lifecycle and HOME
handling are kept; *System → Original Home* still opens LG's ribbon, and BLUE
comes back.

### How it works on webOS 10

LG's Home is a Flutter app that cannot be extended, so the launcher is its own
app:

- `org.rawin.launcher` — a developer QML app with an overlay window, run by
  `qml-runner`. The *Input Hook* homebrew app sends the HOME button to it. BACK
  hides the window but keeps the process, so the next HOME usually only has
  to show it.
- `org.rawin.launcher.service` — a Node service in the same package, given root
  with the Homebrew Channel's `elevate-service`. webOS 10 answers no Luna calls
  from a developer QML app, so the helper lists apps and inputs, launches apps
  and reads the TV language, and serves them to the panel over HTTP on
  `127.0.0.1:8899` (loopback only). It also watches the foreground: when an app
  exits or LG Home comes up uninvited it opens the last input (or the HDMI
  chosen in the settings).
- LG Home stand-in — a black web page with the id `com.webos.app.home`,
  bind-mounted over `/usr/palm/applications/com.webos.app.home` at every boot.
  The app manager is made to re-read Home with a block and release of that one
  app (the same approach [Glasshouse](https://github.com/rorygallagher2024/glasshouse)
  uses for its own Home on webOS 10), then LG's Flutter Home is stopped. Anything
  that opens Home — an app's exit, Netflix's BACK hold, a BACK hold on an
  input — gets the black page instead, and the helper switches to the input.
  Install with `--keep-lg-home` to skip this; *System → Original Home* then
  opens LG's Home.

## Requirements

- A rooted TV with the [Homebrew Channel](https://github.com/webosbrew/webos-homebrew-channel)
  and a root shell (SSH or telnet, enabled in the Homebrew Channel settings).
- webOS 10: the **Input Hook** app, installed from the Homebrew Channel.
- The TV's own `node`, `tar` and `curl`/`wget` (present on the tested TVs).

## Install (on the TV, from a terminal)

Log in to the TV as root (`ssh root@<tv-ip>`, or `telnet <tv-ip>`), then:

```sh
cd /tmp
curl -fL -o rawin-launcher.tar.gz https://github.com/rawinek/rawin-launcher/releases/latest/download/rawin-launcher.tar.gz
rm -rf rawin-launcher && tar xzf rawin-launcher.tar.gz
sh rawin-launcher/install.sh
```

With wget instead of curl: `wget -O rawin-launcher.tar.gz <the same URL>`.
This always takes the latest release; for another one, download
`rawin-launcher.tar.gz` from its page under
[Releases](https://github.com/rawinek/rawin-launcher/releases). On webOS 10,
add `--keep-lg-home` to leave LG's Home in place. The installer picks
the variant for the TV's webOS, prints each step and ends with "Press HOME on
the remote".

No internet on the TV, or the download fails (older TVs can lack current TLS
certificates)? Download `rawin-launcher.tar.gz` on a computer and copy it over:

```sh
cat rawin-launcher.tar.gz | ssh root@<tv-ip> 'cat > /tmp/rawin-launcher.tar.gz'
```

and continue on the TV with `tar xzf` and `install.sh` as above.

## Updating

Favourites and settings are kept by every update, manual or from the TV.

### From a version before 0.10.0 (once, by hand)

Versions before 0.10.0 have no updater, so the first update goes the same way
as the install: log in to the TV as root and run the four install commands
again.

```sh
cd /tmp
curl -fL -o rawin-launcher.tar.gz https://github.com/rawinek/rawin-launcher/releases/latest/download/rawin-launcher.tar.gz
rm -rf rawin-launcher && tar xzf rawin-launcher.tar.gz
sh rawin-launcher/install.sh
```

The installer replaces the old version in place; nothing needs to be
uninstalled first. On webOS 10 add `--keep-lg-home` again if it was installed
with it. Press HOME afterwards; *System* shows the new version in its corner.

### From 0.10.0 on (on the TV)

1. Open *System → Launcher settings → Updates*. The launcher checks GitHub
   each time the settings open and shows *Up to date* or *Version x.y.z is
   available*.
2. OK downloads the new release and checks its SHA-256 against the one
   GitHub publishes (*x.y.z downloaded and verified*).
3. A second OK installs it with the same `install.sh` (*Installing x.y.z…*).
   The launcher restarts by itself after a few seconds. On webOS 10 the
   `--keep-lg-home` choice is kept.

*Launcher settings → Test builds* also offers pre-releases. If a step fails,
the panel says so and OK tries again; the installer's output is in
`/tmp/rawin-launcher-update/install.log`.

Behind the button is `update.sh` next to the installed launcher, run as root
(webOS 4: through the Homebrew Channel's `exec` service; webOS 10: by the
helper). It can also be run by hand, one step at a time:

```sh
sh /var/lib/webosbrew/rawin-launcher/update.sh check   # webOS 10: /var/lib/webosbrew/rawin-launcher-home/update.sh
sh /var/lib/webosbrew/rawin-launcher/update.sh download
sh /var/lib/webosbrew/rawin-launcher/update.sh install
```

The manual way above keeps working too, for any version.

## Uninstall

On the TV, from the unpacked release or the installed copy:

```sh
sh rawin-launcher/uninstall.sh
# or, without the release:
sh /var/lib/webosbrew/rawin-launcher/uninstall.sh        # webOS 4
sh /var/lib/webosbrew/rawin-launcher-home/uninstall.sh   # webOS 10
```

LG's Home and the HOME button are given back at once; nothing needs a reboot.

## What it changes on the TV

Nothing on the read-only system partition is written. Everything below is
removed by the uninstaller.

webOS 4:

| What | Where |
| :--- | :--- |
| Launcher files, patched and original Home QML | `/var/lib/webosbrew/rawin-launcher/` |
| Boot hook (bind mounts, CRIU snapshot hidden, Home restarted) | `/var/lib/webosbrew/init.d/76-rawin-launcher` |
| Favourites and settings | LG Home's LocalStorage (database `rawinLauncher`) |

webOS 10:

| What | Where |
| :--- | :--- |
| App and helper (developer app) | `org.rawin.launcher`, `org.rawin.launcher.service` |
| Helper runs as root | Homebrew `elevate-service` role files for the service |
| LG Home stand-in, its script, the uninstaller | `/var/lib/webosbrew/rawin-launcher-home/` |
| Boot hook (stand-in mounted, helper started) | `/var/lib/webosbrew/init.d/77-rawin-launcher` |
| HOME button → launcher | Input Hook `keybinds.json`, key `773` (first copy kept as `keybinds.json.before-rawin-launcher`) |
| Last input, BACK-hold target | `/var/lib/webosbrew/rawin-launcher-last-input`, `rawin-launcher-settings.json` |
| Favourites and settings | the app's LocalStorage (database `rawinLauncher`) |

`773` is the HOME button of the tested Magic Remote as Input Hook reports it.
If HOME does nothing on another remote, press it once and read the code from
Input Hook's log (`/tmp/lginput-hook-*.log`), then change it in
`keybinds.json`.

## Recovery

- webOS 4: deleting `/var/lib/webosbrew/init.d/76-rawin-launcher` and
  rebooting gives LG's Home back, since the bind mounts end with a reboot.
- webOS 10: `sh /var/lib/webosbrew/rawin-launcher-home/takeover.sh restore`
  gives LG's Home back until the next boot; `takeover.sh status` shows which
  Home the TV has. If the app manager does not accept the stand-in, the script
  unmounts it and leaves LG's Home.
- If a boot hook ever crashes the start-up, the Homebrew Channel's failsafe mode
  skips all hooks on the next boot.

## Troubleshooting

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
Copy it to a computer with `ssh root@<tv-ip> cat /tmp/rawin-launcher-diagnose.txt > diagnose.txt`
and attach it to an [issue](https://github.com/rawinek/rawin-launcher/issues).

## Build from source

Python 3 on any computer:

```sh
python3 tools/build.py                   # dist/rawin-launcher.tar.gz
python3 tools/build.py --config my.json  # with your own favourites
python3 tools/deploy.py --host <tv-ip>   # build, copy over SSH and run install.sh
```

`config/launcher.json` can preset favourites (up to seven app ids, empty by
default; apps that are not installed are skipped), the glow colour per app and
the apps hidden from the lists. Preset favourites only fill a fresh install:
once favourites are edited on the TV, that list stays, also through updates.
`tools/make-icon.py` draws `ui/icon.png`.

Layout: `ui/` the panel shared by both variants (`Launcher.qml`, texts in
`Strings.js`, LocalStorage in `FavouriteStore.qml`, fonts); `webos4/` the
patch, boot hook and scripts; `webos10/` the overlay app, helper, HTTP bridge,
stand-in and scripts; `tools/` build and deploy.

Adding a language: copy the `en` table in `ui/Strings.js`, translate it and add
the code to `languages` and `names`.

## Credits

- [webOS Homebrew Channel](https://github.com/webosbrew/webos-homebrew-channel)
  for root, `elevate-service` and the boot hooks, and Input Hook for the HOME
  button.
- [Glasshouse](https://github.com/rorygallagher2024/glasshouse) showed how the
  app manager re-reads LG's Home on webOS 10 (block and release of one app).
- [Inter](https://github.com/rsms/inter) typeface, SIL Open Font License 1.1.
- Video in the screenshots: *Big Buck Bunny* © Blender Foundation,
  [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/).

## Disclaimer

Unofficial; not affiliated with or endorsed by LG Electronics. It runs as root
on your TV and replaces how its home screen works. Use at your own risk.

## License

MIT, see [LICENSE](LICENSE). The Inter font is under the SIL Open Font License
1.1 (`ui/fonts/OFL.txt`).
