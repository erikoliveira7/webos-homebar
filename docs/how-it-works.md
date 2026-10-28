# How it works

Both variants show the same panel, `ui/Launcher.qml`; they differ in how it
gets on screen and talks to the TV. Which one a TV gets is in
[Compatibility](compatibility.md#which-variant-a-tv-gets).

- [The Home panel (webOS 4)](#the-home-panel-webos-4)
- [The overlay (webOS 10)](#the-overlay-webos-10)
- [The panel on any screen](#the-panel-on-any-screen)
- [What it changes on the TV](#what-it-changes-on-the-tv)
- [Names](#names)

## The Home panel (webOS 4)

LG's Home (`com.webos.app.home`) is a QML app. `webos4/patch-home.js` makes a
copy of its `main.qml` with a `Loader` for the launcher panel on top of LG's UI,
and of `Controllers/UIController.qml` so LG's ribbon stays out of the way. A
Homebrew boot hook bind-mounts the two files over the firmware ones, hides
Home's CRIU snapshot (which would otherwise restore the original QML from
memory) and restarts only the Home process. LG's window, lifecycle and HOME
handling are kept; *System → Original Home* still opens LG's ribbon, and BLUE
comes back.

The patch finds its places in LG's files rather than counting on one
firmware: the root element and its id, LG's UI controller and Home's
foreground state must be there; the smaller pieces are patched where they
match. Should the panel fail to load, LG's own UI shows as before.

## The overlay (webOS 10)

LG's Home is a Flutter app that cannot be extended, so the launcher is its own
app:

- `org.rawin.launcher`: a developer QML app with an overlay window, run by
  `qml-runner`. Its Launcher settings menu is a separate component, built the
  first time the menu is opened (or in the first quiet moment after the panel
  appears), so the panel's own scene stays small and HOME never waits for it.
  The *Input Hook* homebrew app sends the HOME button to it:
  HOME shows the panel, or hides it when it is already up. BACK hides the
  window but keeps the process, so the next HOME only has to show it. The
  boot hook starts the app once the helper is up (a launch with
  `{"preload": true}`, without the app manager's spinner and splash where
  the launch call takes those flags): the window is shown for half a second
  with nothing drawn, which takes the app manager's loading spinner down,
  and hidden; the first HOME after a boot is then a show too, not a start of
  `qml-runner`. A preload that lands after a HOME has already started the
  app changes nothing. The helper watches the process (in `/proc`, since a
  closed panel cannot be asked): when it is gone — the system closed it for
  memory, or a preload failed — it starts it hidden again, with
  `keepAlive: true` so the app manager keeps it while other apps run. That
  only happens while nothing but an input, LG's Home or an empty screen is
  in front (a launch during a video app would briefly take the screen), and
  not while a restart is under way. Since launching any app closes the panel,
  it also starts it again while an app is in front — 2.5 s after that app
  came to the front (and a check every 10 s), at most once every 15 s, and
  with `quiet: true`, which skips the window entirely (nothing can flash
  over the picture); on the tested B4 the app stayed in front and the next
  HOME was a show. The first HOME after a boot still waits
  for the hooks; this covers the "sometimes 3–5 seconds" case later on. The
  Homebrew Channel runs its hooks in name order
  some 40 s into a boot; the launcher's is named to run among the first and
  starts Input Hook's service as its first step (the service puts its
  library into the input processes as it loads, once per boot), so HOME
  reaches the launcher a few seconds after the hooks begin (42 s after
  power-on on the tested B4). A HOME before then opens LG's Home once (see
  [Troubleshooting](troubleshooting.md#home-right-after-a-boot-opens-lgs-home-overlay)).
  The boot hook and the stand-in note each step in
  `/tmp/rawin-launcher-boot.log` with the seconds since boot.
- `org.rawin.launcher.service`: a Node service in the same package, given root
  with the Homebrew Channel's `elevate-service`. webOS 10 answers no Luna calls
  from a developer QML app, so the helper lists apps and inputs, launches apps
  and reads the TV language, and serves them to the panel over HTTP on
  `127.0.0.1:8899` (loopback only). It also watches the foreground: when an app
  exits or LG Home comes up uninvited it opens the last input (or the HDMI
  chosen in the settings). It keeps the backup file (`backup.json`) for the
  panel, and runs the [setup server](#the-weather-and-its-page) for the
  weather. It is written for node 8 and later. When it does not answer (a
  HOME in the second before it is up after a boot, an update replacing it),
  the panel asks for the app list again every 1.5 s, up to ten times.
- LG Home stand-in: a black web page with the id `com.webos.app.home`,
  bind-mounted over `/usr/palm/applications/com.webos.app.home` at every boot.
  The app manager is made to re-read Home with a block and release of that one
  app (the same approach [Glasshouse](https://github.com/rorygallagher2024/glasshouse)
  uses for its own Home on webOS 10), then LG's Home is stopped. Anything
  that opens Home (an app's exit, Netflix's BACK hold, a BACK hold on an
  input) gets the black page instead, and the helper switches to the input.
  Install with `--keep-lg-home` to skip this; *System → Original Home* then
  opens LG's Home. On an untested webOS the stand-in is skipped unless
  `--replace-lg-home` asks for it. With Glasshouse's Home switched on
  (`"enabled": true` in `/var/lib/tvweb/home.json`), Home is Glasshouse's:
  the stand-in is not mounted and the helper does not switch away from it.

## Experimental direct Home

On the `codex/native-home-release` branch, automatic installation stages the same
panel as `com.webos.app.home` on webOS 10/11. The firmware's QML runner is the
native host and registers lifecycle v2 with SAM, which dispatches HOME directly.
The window remains an overlay. This replaces the black stand-in and the
recognised Homebar Input Hook/Magic Mapper bindings, rather than adding another renderer.
The helper still supplies services. Native after-exit redirection runs only when
an app leaves no card, using the selected last input, TV or physical input; it
does not redirect ordinary HOME. Its standard Home-triggered redirection and
process preloader are disabled in this mode. Restart targets the Home host.
`native-home.sh disable` copies Homebar's database back and restores the prior
Homebar bindings during teardown; it retains other user key bindings. Runtime mode
switching is deferred to `codex/native-home-modes`. See
[the experiment](experiments.md#direct-system-home-experimental-branch).

## The panel on any screen

The panel is drawn for 1920×1080 and scales every length to the size it is
given (`u` and `px()` in `Launcher.qml`): LG's UI runs at 1280×720 on HD
TVs, and the overlay takes that size when the screen reports it. Positions
hang from the bottom and the right edge, so a wider screen gets a longer
rail and more columns in *Apps*. The Home rail gives the input pills what is
left after the favourites and the two doors, and cuts the device names under
*HDMI n* to that, so the rail never runs past the right margin; the TV's
inputs come from the TV, as many as it has.

Opening Home is kept cheap on a TV's GPU: the app and input lists are read
again each time but only replace the old ones when they changed, so the tiles
are not torn down and built again; the glow in the corner is drawn only where
it reaches; the *Apps* grid builds only the rows on screen and the next one.

The glow colour of an app the build has no colour for is read from its icon:
the icon is drawn 24 pixels wide on a hidden canvas and its vivid pixels
averaged (grey, white and black count for little; a dark result is
brightened), once per icon, and kept with the icon's path so a changed icon
is read again.

## The weather and its page

Both variants run the same small server, `shared/setup.js` (plain ES5, for
webOS 4's node 0.12), on port 8898: the overlay's helper starts it in its own
process, and on webOS 4 the boot hook starts it as its own `node` process.
It serves:

- `/weather` and `/info`, to the panel on `127.0.0.1` only: the weather now
  (Open-Meteo, over plain HTTP: node 0.12's TLS is too old for most of the
  web) and the address of the place page, with that address as a QR code
  (`shared/qr.js`), which the panel draws on a `Canvas`.
- `/` and `/place`, to the home network: the page a phone opens from the
  code, and the place it saves. The page looks the place up with
  Open-Meteo's geocoding from the phone itself. Saving needs the token in
  the code, which is new each time the server starts.

What goes out: the place's coordinates to Open-Meteo, at most once a quarter
of an hour, and, while no place is chosen, one request to ip-api.com every
six hours, which sees the TV's internet address. Only the chosen place is
kept, in `weather.json` next to the installed launcher. With *Weather* off
the panel asks for nothing.

## What the launcher keeps

Everything the launcher remembers is in its LocalStorage database
(`rawinLauncher`): `favourites` (app ids), `settings`, `hidden` and
`hiddenInputs` (ids hidden with RED), `usage` (how often each app was opened
from here, for the "most used" order) and `colors` (the glow colours read
from icons). *Back up* writes the first five to `backup.json` next to the
installed launcher: with the Home panel through the Homebrew Channel's
`exec` (the JSON in a `printf`), with the overlay through the helper
(`POST /backup`, `GET /restore`).

The settings menu is drawn by the panel itself (no Qt Quick Controls, which
the TVs' Qt does not have in one shape): a card in the theme's tile colour,
a scrolling column of rows on the left, the focused setting's values on the
right; the positions of the rows are added up from their heights rather
than read from the column, which places them only a frame later.

## What it changes on the TV

Nothing on the read-only system partition is written. Everything below is
removed by the [uninstaller](install.md#uninstall).

Home panel:

| What | Where |
| :--- | :--- |
| Launcher files, patched and original Home QML, the scripts (`update.sh`, `diagnose.sh`, `probe.sh` with `patch-home.js`), the setup server (`setup/`, `setup.pid`), `backup.json` and `weather.json` once made | `/var/lib/webosbrew/rawin-launcher/` |
| Boot hook (bind mounts, CRIU snapshot hidden, Home restarted, setup server started) | `/var/lib/webosbrew/init.d/76-rawin-launcher` |
| Favourites and settings | LG Home's LocalStorage (database `rawinLauncher`) |

Overlay:

| What | Where |
| :--- | :--- |
| App and helper (developer app) | `org.rawin.launcher`, `org.rawin.launcher.service` |
| Helper runs as root | Homebrew `elevate-service` role files for the service |
| LG Home stand-in, its script, the uninstaller, the scripts (`update.sh`, `diagnose.sh`, `probe.sh` with `patch-home.js`), `backup.json` and `weather.json` once made | `/var/lib/webosbrew/rawin-launcher-home/` |
| Boot hook (Input Hook started, stand-in mounted, helper started, panel preloaded) | `/var/lib/webosbrew/init.d/10-rawin-launcher` (`77-rawin-launcher` up to 0.14.0) |
| HOME button → launcher | Input Hook `keybinds.json`: the key pressed when the installer asked, else `773` (first copy kept as `keybinds.json.before-rawin-launcher`) |
| Last input, BACK-hold target | `/var/lib/webosbrew/rawin-launcher-last-input`, `rawin-launcher-settings.json` |
| Favourites and settings | the app's LocalStorage (database `rawinLauncher`) |

`773` is the HOME button of the tested Magic Remote as Input Hook reports it;
run from a terminal, the installer asks for a press of HOME and takes the
code Input Hook logs for it, see
[Troubleshooting](troubleshooting.md#home-does-nothing-overlay).

## Names

Homebar was called rawin-launcher until 0.12.0, and kept that name on the TV:
the release file `rawin-launcher.tar.gz`, the folders under
`/var/lib/webosbrew/`, the boot hooks, the app id `org.rawin.launcher` and the
LocalStorage database. So an update from any earlier version replaces the
files in place and keeps favourites and settings, and the updaters already on
TVs (which look for `rawin-launcher.tar.gz` at `rawinek/rawin-launcher`, now a
redirect to `rawinek/webos-homebar`) keep finding new releases. The two
variants were called "webOS 4" and "webOS 10" until 0.12.1, after the TVs
they were made on; the installer's `--try-webos10` still means `--overlay`.
