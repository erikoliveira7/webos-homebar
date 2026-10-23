# Install, update, uninstall

- [Requirements](#requirements)
- [Install](#install)
- [Update](#update)
- [Uninstall](#uninstall)

## Requirements

- A rooted TV with the [Homebrew Channel](https://github.com/webosbrew/webos-homebrew-channel)
  and a root shell (SSH or telnet, enabled in the Homebrew Channel settings).
- webOS 10: the **Input Hook** app, installed from the Homebrew Channel.
- The TV's own `node`, `tar` and `curl`/`wget` (present on the tested TVs).

Which webOS versions work is in [Compatibility](compatibility.md).

## Install

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
[Releases](https://github.com/rawinek/rawin-launcher/releases). The installer
picks the variant for the TV's webOS, prints each step and ends with "Press
HOME on the remote".

Installer options:

| Option | What it does |
| :--- | :--- |
| `--keep-lg-home` | webOS 10: leave LG's Home in place; *System → Original Home* opens it |
| `--try-webos10` | webOS 5–9 and 11 (untested): install the webOS 10 variant, with LG's Home kept |
| `--replace-lg-home` | With `--try-webos10`: also put the black stand-in in place of LG's Home |

### Without internet on the TV

The download can fail with no internet, or on older TVs that lack current TLS
certificates. Download `rawin-launcher.tar.gz` on a computer and copy it over:

```sh
cat rawin-launcher.tar.gz | ssh root@<tv-ip> 'cat > /tmp/rawin-launcher.tar.gz'
```

then continue on the TV with `tar xzf` and `install.sh` as above.

## Update

Favourites and settings are kept by every update, manual or from the TV.

### From the TV (0.10.0 and later)

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

### By hand (any version, and once from before 0.10.0)

Versions before 0.10.0 have no updater, so the first update goes the same way
as the install: log in to the TV as root and run the four
[install commands](#install) again. The installer replaces the old version in
place; nothing needs to be uninstalled first. On webOS 10 add `--keep-lg-home`
again if it was installed with it. Press HOME afterwards; *System* shows the
new version in its corner.

## Uninstall

On the TV, from the unpacked release or the installed copy:

```sh
sh rawin-launcher/uninstall.sh
# or, without the release:
sh /var/lib/webosbrew/rawin-launcher/uninstall.sh        # webOS 4
sh /var/lib/webosbrew/rawin-launcher-home/uninstall.sh   # webOS 10
```

LG's Home and the HOME button are given back at once; nothing needs a reboot.
What the uninstaller removes is listed in
[How it works → What it changes on the TV](how-it-works.md#what-it-changes-on-the-tv).
