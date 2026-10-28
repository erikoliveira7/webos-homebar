# Install, update, uninstall

- [Requirements](#requirements)
- [Install](#install)
- [Update](#update)
- [Uninstall](#uninstall)

## Requirements

- A rooted TV with the [Homebrew Channel](https://github.com/webosbrew/webos-homebrew-channel)
  and a root shell (SSH or telnet, enabled in the Homebrew Channel settings).
- Overlay builds need node 8 or newer. The Home-panel variant uses the TV's
  older node runtime and does not need a mapper.
- On this development branch, webOS 10/11 use direct system HOME without
  requiring Input Hook. Other overlay installs require Input Hook or an existing
  supported Magic Mapper HOME shortcut. Published 0.18.0 uses the previous
  overlay and requires Input Hook.
- The TV's own `node`, `tar` and `curl`/`wget` (present on the tested TVs).
- For the Home panel on a TV with LG's two Home screens (some 2019 models):
  the TV's *Home screen* setting on *Basic*, see
  [Compatibility](compatibility.md#webos-versions).

Which webOS versions work, and which variant a TV gets, is in
[Compatibility](compatibility.md).

## Install

Log in to the TV as root (`ssh root@<tv-ip>`, or `telnet <tv-ip>`), then:

```sh
cd /tmp
curl -fL -o rawin-launcher.tar.gz https://github.com/rawinek/webos-homebar/releases/latest/download/rawin-launcher.tar.gz
rm -rf rawin-launcher && tar xzf rawin-launcher.tar.gz
sh rawin-launcher/install.sh
```

With wget instead of curl: `wget -O rawin-launcher.tar.gz <the same URL>`.
This always takes the latest release; for another one, download
`rawin-launcher.tar.gz` from its page under
[Releases](https://github.com/rawinek/webos-homebar/releases). The installer
says which webOS it found, picks the variant the TV has the makings for,
prints each step and ends with "Press HOME on the remote". The file and the
folder keep the project's first name, `rawin-launcher`, as do the installed
files (see [How it works → Names](how-it-works.md#names)).

Installer options:

| Option | What it does |
| :--- | :--- |
| `--probe` | Only says which variant fits this TV and why; changes nothing |
| `--home-panel` | The panel inside LG's Home, or fail (no overlay instead) |
| `--overlay` | The helper-based installation; system HOME on webOS 10/11, compatibility overlay elsewhere |
| `--keep-lg-home` | Compatibility overlay only: leave LG's Home in place; *System → Original Home* opens it |
| `--replace-lg-home` | Compatibility overlay on an untested webOS: put the black stand-in in LG Home's place anyway (unavailable with system HOME) |
| `--native-home` | Experimental system Home takeover on webOS 10/11, without an Input Hook binding; branch builds only. See [experiments](experiments.md#direct-system-home-experimental-branch) |
| `--home-key=CODE` | Compatibility overlay: bind this key code as HOME (the number Input Hook logs for it) |
| `--home-key=ask` | Compatibility overlay: ask for a press of HOME, also when a key is already bound |
| `--home-key-exec` | Compatibility overlay: send that press through Input Hook's *Execute* action with `noSplash`/`spinner:false`, so the app manager does not show its loading spinner when the panel has to start. Experimental: Input Hook must be able to run commands, so try it and keep the plain binding if HOME stops opening the panel |
| `--try-webos10` | The same as `--overlay`; older instructions use it |

On the compatibility overlay the installer, run from a terminal, asks for a press of HOME
and binds the key Input Hook logs for it (15 s; without a press, the tested
Magic Remote's `773`). An install that finds the launcher already bound to a
key keeps that key; an update from the panel never asks. The panel is started
hidden at boot and kept across HOMEs, and the helper starts it again if the
system closed it, so a HOME is normally a show rather than a start (see
[How it works](how-it-works.md#the-overlay-webos-10)).

### Without internet on the TV

The download can fail with no internet, or on older TVs that lack current TLS
certificates. Download `rawin-launcher.tar.gz` on a computer and copy it over:

```sh
cat rawin-launcher.tar.gz | ssh root@<tv-ip> 'cat > /tmp/rawin-launcher.tar.gz'
```

then continue on the TV with `tar xzf` and `install.sh` as above.

## Update

Favourites and settings are kept by every update, manual or from the TV, and
so are the variant and the `--keep-lg-home` choice.

### From the TV (0.10.0 and later)

1. Open *System → Launcher settings → Updates*. The launcher checks GitHub
   each time the settings open and shows *Up to date* or *Version x.y.z is
   available*.
2. OK downloads the new release and checks its SHA-256 against the one
   GitHub publishes (*x.y.z downloaded and verified*).
3. A second OK installs it with the same `install.sh` (*Installing x.y.z…*).
   The launcher restarts by itself after a few seconds.

*Launcher settings → Test builds* also offers pre-releases. If a step fails,
the panel says so and OK tries again; the installer's output is in
`/tmp/rawin-launcher-update/install.log`.

Behind the button is `update.sh` next to the installed launcher, run as root
(Home panel: through the Homebrew Channel's `exec` service; overlay: by the
helper). It can also be run by hand, one step at a time:

```sh
sh /var/lib/webosbrew/rawin-launcher/update.sh check   # overlay: /var/lib/webosbrew/rawin-launcher-home/update.sh
sh /var/lib/webosbrew/rawin-launcher/update.sh download
sh /var/lib/webosbrew/rawin-launcher/update.sh install
```

### By hand (any version, and once from before 0.10.0)

Versions before 0.10.0 have no updater, so the first update goes the same way
as the install: log in to the TV as root and run the four
[install commands](#install) again. The installer replaces the old version in
place; nothing needs to be uninstalled first. On the overlay add
`--keep-lg-home` again if it was installed with it. Press HOME afterwards;
*System* shows the new version in its corner, with the TV's webOS and the
variant.

## Uninstall

On the TV, from the unpacked release or the installed copy:

```sh
sh rawin-launcher/uninstall.sh
# or, without the release:
sh /var/lib/webosbrew/rawin-launcher/uninstall.sh        # Home panel
sh /var/lib/webosbrew/rawin-launcher-home/uninstall.sh   # overlay
```

LG's Home and the HOME button are given back at once; nothing needs a reboot.
What the uninstaller removes is listed in
[How it works → What it changes on the TV](how-it-works.md#what-it-changes-on-the-tv).

## System HOME on this development branch

On webOS 10/11, both fresh installs and upgrades select direct system HOME
(takeover). Older ribbon-Home TVs keep the Home-panel integration; other webOS
versions retain the mapper-based compatibility overlay. webOS 10.3 has been
verified on B4; webOS 11 is gated as supported by the implementation but still
needs real-TV validation. No new mode is added to C9.

```sh
sh install.sh              # automatic platform selection
sh install.sh --native-home # explicit system HOME on webOS 10/11
sh install.sh --probe       # read-only capability and conflict checks
```

Before changing a supported newer TV, the installer checks Home ownership and
mapper configuration. Another launcher owning HOME, a conflicting HOME action,
or configuration that cannot be safely inspected blocks installation; resolve
the reported conflict and retry. Homebar never silently replaces another launcher.
An experimental additional-overlay install must first be restored using its own
branch; this build does not convert it automatically.

Recognised Homebar rules in Input Hook and supported Magic Mapper configurations
are backed up and removed during migration, including older Homebar shortcuts
on other buttons. Other actions and mapper settings stay. Active supported Magic
Mapper is restarted; a failed reload rolls back the change. Favourites and
settings are copied to the system Home host. A transaction journal supports
rollback and recovery after interrupted migration.

There is no Launch method setting, companion-overlay option or runtime mode
switch API in this branch. Those features are deferred. The internal migration
script handles installation/recovery only. Uninstall restores LG Home and removes
only recognised Homebar mappings; it does not uninstall either mapper.

Do not install a published/older overlay-only release over native Home until
native ownership is restored using this build's uninstall procedure.
