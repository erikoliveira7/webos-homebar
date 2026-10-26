// Keeps the overlay panel's process resident between HOMEs. The app is started
// hidden at boot and BACK only hides its window, so a HOME is a show — unless
// the system closed the process (memory, an app switch, a failed preload at
// boot); then HOME has to start qml-runner again, which is the 3–5 seconds
// people notice. This starts it with {"preload": true} again when it is gone,
// with keepAlive asking the app manager to keep it while other apps run.
//
// It acts while nothing but an input, LG's Home or an empty screen is in
// front (a normal preload: the window is mapped for a moment to take the app
// manager's loading spinner down), and — because launching any app closes the
// panel — also, more rarely, while an app is in front: then the launch is
// quiet (no window at all), which on the tested B4 left the app in front and
// its picture untouched, and makes the next HOME a show. It also stays still
// for a moment after a restart was asked for, which closes and starts the app
// itself.
//
// Pure logic: the caller provides the running check, the launch, the clock and
// a log, so the decisions can be tested without a TV.
'use strict';

const APP = 'org.rawin.launcher';
const APP_DIR = '/media/developer/apps/usr/palm/applications/' + APP;
// What may be full-screen while the panel is started again: nothing, the
// panel itself, LG's Home (or the stand-in under its id) and the inputs.
const SAFE_FOREGROUND = /^(|org\.rawin\.launcher|com\.webos\.app\.(home|hdmi[1-4]|livetv|dp[12]|usbc[12]|externalinput\..+))$/;

// Every foreground app id is one of those (an app in front is not).
function foregroundSafe(ids) {
  return ids.every((id) => SAFE_FOREGROUND.test(id || ''));
}

// Is qml-runner running the app? Its argv holds the app's folder. Reading
// /proc is what works on every webOS here; applicationManager's listRunning
// does not exist on webOS 4 and its getAppStatus means different things on
// different versions.
function panelRunning(fsMod, appDir) {
  const dir = appDir || APP_DIR;
  let pids;
  try { pids = fsMod.readdirSync('/proc'); } catch (e) { return false; }
  for (let i = 0; i < pids.length; i++) {
    if (!/^[0-9]+$/.test(pids[i])) continue;
    try {
      if (fsMod.readFileSync('/proc/' + pids[i] + '/cmdline', 'utf8').indexOf(dir) >= 0) return true;
    } catch (e) {}   // the process ended between the listing and the read
  }
  return false;
}

class Preloader {
  // isRunning: () => boolean; launch: (quiet) => Promise<{returnValue, errorText}>
  constructor({ isRunning, launch, now = Date.now, log = () => {},
                tryGapMs = 60000, appGapMs = 15000 }) {
    this.isRunning = isRunning;
    this.launch = launch;
    this.now = now;
    this.log = log;
    this.tryGapMs = tryGapMs;
    this.appGapMs = appGapMs;
    this.lastTryAt = -Infinity;
    this.pausedUntil = 0;
    this.count = 0;
    this.lastResult = '';
  }

  // A restart closes and starts the app itself; keep out of its way.
  pause(ms) { this.pausedUntil = this.now() + ms; }

  state() { return { count: this.count, last: this.lastResult, running: this.isRunning() }; }

  // state: 'free' (nothing, an input, LG's Home or the panel itself in front),
  // 'app' (an app is in front, so only a quiet start), or 'unknown'.
  async tick(state) {
    if (state !== 'free' && state !== 'app') { this.lastResult = 'unknown'; return false; }
    const t = this.now();
    if (t < this.pausedUntil) { this.lastResult = 'paused'; return false; }
    if (t - this.lastTryAt < (state === 'app' ? this.appGapMs : this.tryGapMs)) return false;
    if (this.isRunning()) { this.lastResult = 'running'; return false; }
    this.lastTryAt = t;
    const r = await this.launch(state === 'app');
    this.count++;
    const ok = !!(r && r.returnValue);
    this.lastResult = ok ? 'preloaded' : 'failed: ' + ((r && r.errorText) || 'no answer');
    this.log('panel ' + this.lastResult + (this.count > 1 ? ' (try ' + this.count + ')' : ''));
    return ok;
  }
}

module.exports = { Preloader, panelRunning, foregroundSafe, APP, APP_DIR, SAFE_FOREGROUND };
