# Experiments

Things tried on the test TVs that are not part of the release. Each has its
own script; none is run by the installer.

## The LG Home stand-in as a package (overlay)

The overlay puts the black stand-in in LG Home's place with a bind mount at
every boot. The Homebrew Channel runs the boot hooks some 35 s after
power-on, and a HOME before that opens LG's own Home once
([Troubleshooting](troubleshooting.md#home-right-after-a-boot-opens-lgs-home-overlay)).

LG updates its built-in apps by installing a higher version of the same id
outside the firmware, and the app manager takes that copy over the one in
the firmware. If it does the same for `com.webos.app.home` from a developer
install, the stand-in as a package with version `99.0.0` is LG's Home from
the first second of a boot, with nothing to mount.

```sh
python3 tools/build-home-override.py          # dist/home-override/: the IPK and the script
scp dist/home-override/* root@<tv-ip>:/tmp/ovr/
ssh root@<tv-ip> sh /tmp/ovr/home-override.sh install   # or status, remove
```

`install` prints what the app manager reports for Home before and after
(where it reads it from, its type and version) and a verdict. `remove` takes
the package away; LG's Home is as before. The launcher's own install is not
touched; `takeover.sh restore` and a `keep-lg-home` file in
`/var/lib/webosbrew/rawin-launcher-home/` keep the bind mount out of the
way for a clean look.

What a HOME before the hooks would then show is the black page, until the
helper comes up and switches to the input: black for up to 15 s instead of
LG's Home for as long.

Result, B4 (webOS 10.3.1): **refused**. The developer installer parses the
package, closes the running Home, then fails with error -15, *Cannnot
install privileged app on developer mode*; nothing is written. An id under
`com.webos.` is privileged, and the developer installer will not take one.

### The copy by hand

The refusal is the developer installer's, not the app manager's. LG's own
updates of built-in apps go to `/media/cryptofs/apps/usr/palm/applications/`
(the store apps area), which the app manager reads at boot. `place` copies
the same files there by hand, as root; a reboot then shows whether the app
manager takes a higher version of Home from that area. `remove` deletes the
copy; it is gone from the app manager at the next boot.

Result, B4 (webOS 10.3.1): **works**. After a reboot the app manager reads
Home from the copy (`folderPath` in the store area, version 99.0.0, type
web), and a HOME before the hooks run launches the stand-in, which shows
nothing (the input stays on screen; a system "wait" toast on the first
press); LG's Home did not appear in three boots. The bind mount of the boot
hook goes on top without error.

Not taken into the release: it only matters in the first 40 s after a cold
boot, which a TV woken from standby never sees, and it would need its own
uninstall (the copy has to be removed, and the TV rebooted, before LG's
Home is back) and watching over LG's store and firmware updates. A TV
that tried it keeps the copy until `home-override.sh remove` and a reboot.

## Direct system Home

`--native-home` uses the TV's existing native QML host directly as
`com.webos.app.home`, with the same Homebar overlay UI. System HOME reaches
that instance without an Input Hook binding. The host registers lifecycle v2
with the application manager; this does not replace Qt or rewrite the panel.
It accepts webOS 10/11 only; B4 on 10.3.1 was tested, including startup after
a system reboot. webOS 11 has not been tested. It does not change the Home
panel used on older TVs. This is what a fresh install on webOS 10/11 uses.

From the unpacked release:

```sh
sh rawin-launcher/install.sh --native-home
```

Do not combine this with another Home replacement or `--keep-lg-home`.
The installer removes only recognised Input Hook and Magic Mapper bindings targeting Homebar, leaving other
button mappings alone. Files are bind-mounted over Home; original system files
remain underneath. Saved Homebar data is copied to the Home host's storage;
the reverse copy is made when disabling. Updates retain an enabled native mode. Disable it before installing an older
release whose installer does not support native Home. System HOME offers “After holding BACK”: choose the last input, TV or a physical
input. The helper redirects only when an application leaves no full-screen card,
before LG starts its repeated Home/Live TV fallback. Normal HOME over a playing
app still toggles the panel without switching inputs.

To return to the ordinary overlay and its previous Homebar key binding:

```sh
sh /var/lib/webosbrew/rawin-launcher-home/native-home.sh disable
```

Status is available with the same script's `status` command. Uninstall disables
native mode before removing the package. The boot hook reapplies the mount and
starts Home hidden, without starting Input Hook for Homebar. Other tools may
still start Input Hook for their own mappings.

A shorter HOME dispatch path and the system Home identity may improve startup
and process retention. They do not by themselves change the QML rendering cost.
Compare physical HOME, arrow animation, pointer use, app switching and cold boot
before treating this as a performance improvement.

**Launcher settings → Help → Launch method**, allowing
later changes between direct Home and a companion overlay. The companion keeps
another launcher's HOME and does not redirect app exits to HDMI. Its button is
configured separately by the user. A journal restores the previous configuration
and Homebar databases if changing modes fails, and is checked on the next boot
if a change was interrupted. Settings-based switching is locally tested only;
it has not been deployed to a TV.

Fresh automatic installs select a launch method after checking
Home ownership and mapper configuration. Updates preserve the existing choice.
The settings preview shows cleanup and conflicts, with confirmation and a stale
configuration check. Input Hook configuration is saved in place like its own API
(for older watchers), with a recovery journal; Magic Mapper uses an atomic file
replacement and supervised reload when active. Details: [Launch method](using.md#launch-method-overlay-builds).
