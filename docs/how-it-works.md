# How it works

Both variants show the same panel, `ui/Launcher.qml`; they differ in how it
gets on screen and talks to the TV.

- [webOS 4](#webos-4)
- [webOS 10](#webos-10)
- [What it changes on the TV](#what-it-changes-on-the-tv)

## webOS 4

LG's Home (`com.webos.app.home`) is a QML app. `webos4/patch-home.js` makes a
copy of its `main.qml` with a `Loader` for the launcher panel on top of LG's UI,
and of `Controllers/UIController.qml` so LG's ribbon stays out of the way. A
Homebrew boot hook bind-mounts the two files over the firmware ones, hides
Home's CRIU snapshot (which would otherwise restore the original QML from
memory) and restarts only the Home process. LG's window, lifecycle and HOME
handling are kept; *System → Original Home* still opens LG's ribbon, and BLUE
comes back.

## webOS 10

LG's Home is a Flutter app that cannot be extended, so the launcher is its own
app:

- `org.rawin.launcher`: a developer QML app with an overlay window, run by
  `qml-runner`. The *Input Hook* homebrew app sends the HOME button to it. BACK
  hides the window but keeps the process, so the next HOME usually only has
  to show it.
- `org.rawin.launcher.service`: a Node service in the same package, given root
  with the Homebrew Channel's `elevate-service`. webOS 10 answers no Luna calls
  from a developer QML app, so the helper lists apps and inputs, launches apps
  and reads the TV language, and serves them to the panel over HTTP on
  `127.0.0.1:8899` (loopback only). It also watches the foreground: when an app
  exits or LG Home comes up uninvited it opens the last input (or the HDMI
  chosen in the settings).
- LG Home stand-in: a black web page with the id `com.webos.app.home`,
  bind-mounted over `/usr/palm/applications/com.webos.app.home` at every boot.
  The app manager is made to re-read Home with a block and release of that one
  app (the same approach [Glasshouse](https://github.com/rorygallagher2024/glasshouse)
  uses for its own Home on webOS 10), then LG's Flutter Home is stopped. Anything
  that opens Home (an app's exit, Netflix's BACK hold, a BACK hold on an
  input) gets the black page instead, and the helper switches to the input.
  Install with `--keep-lg-home` to skip this; *System → Original Home* then
  opens LG's Home.

## What it changes on the TV

Nothing on the read-only system partition is written. Everything below is
removed by the [uninstaller](install.md#uninstall).

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

`773` is the HOME button of the tested Magic Remote as Input Hook reports it;
for another remote see
[Troubleshooting](troubleshooting.md#home-does-nothing-webos-10).
