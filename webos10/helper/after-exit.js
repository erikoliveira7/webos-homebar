// After an app exits, webOS 10 has no card left (launching the app closed the
// HDMI/TV card) and SAM opens LG Home ~1.5 s later. Instead this goes to the
// input chosen in the launcher settings, or by default the last input card
// (HDMI 1 until another input has been seen): as soon as
// the foreground is empty, before LG Home appears, and whenever LG Home comes
// up without being asked for in our panel. That also covers Netflix, which on a
// BACK hold opens LG Home itself and stays in the background, and a BACK hold
// on an input such as HDMI with no signal.
// Not while another launcher owns Home: Glasshouse's Home runs under LG
// Home's id, so its coming up is no reason to leave it (homeTaken).
// Pure logic: the caller feeds foreground cards and provides launch/now/save.
'use strict';

const HOME = 'com.webos.app.home';
const INPUT = /^com\.webos\.app\.(hdmi[1-4]|livetv|dp[12]|usbc[12]|externalinput\..+)$/;
const DEFAULT_INPUT = 'com.webos.app.hdmi1';
const RETRY_GAP_MS = 1500;     // at most one launch per this period
const HOME_REQUEST_MS = 5000;  // LG Home asked for through the helper (/launch)

function isInput(id) { return INPUT.test(id || ''); }
function isApp(id) { return !!id && id !== HOME && !isInput(id); }

class AfterExit {
  constructor({ launch, later = (fn, ms) => setTimeout(fn, ms), now = Date.now, save = () => {}, lastInput = '', target = '', log = () => {}, homeTaken = () => false, nativeHome = () => false }) {
    this.launch = launch;
    this.later = later;
    this.homeTaken = homeTaken;
    this.nativeHome = nativeHome;
    this.now = now;
    this.save = save;
    this.log = log;
    this.lastInput = isInput(lastInput) ? lastInput : DEFAULT_INPUT;
    this.setTarget(target);
    this.card = null;            // null until the first update
    this.lastLaunchAt = -Infinity;
    this.homeRequestedAt = -Infinity;
  }

  noteHomeRequest() { this.homeRequestedAt = this.now(); }

  // A fixed input from the launcher settings, '' for the last input, or
  // "none": leave the TV to LG (no return at all).
  setTarget(id) { this.none = id === 'none'; this.target = isInput(id) ? id : ''; }

  // card: appId of the full-screen card in front, or '' when there is none.
  onForeground(card) {
    const t = this.now();
    if (isInput(card) && card !== this.lastInput) {
      this.lastInput = card;
      this.save(card);
    }
    if (card === this.card) return;
    const prev = this.card;
    this.card = card;

    const exitToNothing = isApp(prev) && card === '';
    // Native HOME is also a real user action over a playing card. Only an
    // app leaving no card is a return request; redirect before LG's last-input
    // handler opens Home twice and then falls back to Live TV.
    const native = this.nativeHome();
    if (native ? !exitToNothing : !exitToNothing && card !== HOME) return;
    if (this.homeTaken()) { this.log('Home belongs to another launcher; not returning'); return; }
    if (!native && t - this.homeRequestedAt < HOME_REQUEST_MS) { this.log('LG Home was requested; not returning'); return; }
    if (this.none) {
      this.log('return to an input is off');
      // With system HOME there is no LG Home to fall back to: if nothing came up
      // meanwhile, open Homebar rather than leave the screen black.
      if (native) this.later(() => { if (this.card === '' && !this.homeTaken()) this.launch(HOME); }, 4000);
      return;
    }
    if (t - this.lastLaunchAt < RETRY_GAP_MS) return;
    this.lastLaunchAt = t;
    const to = this.target || this.lastInput;
    this.log('from ' + (prev || '?') + ' (now ' + (card || 'empty') + '); to ' + to);
    this.launch(to);
  }
}

// Picks the full-screen card from getForegroundAppInfo({extraInfo:true}).
function cardOf(payload) {
  const list = (payload && payload.foregroundAppInfo) || [];
  const card = list.find((a) => a.windowType === '_WEBOS_WINDOW_TYPE_CARD');
  // Live Dmost is a child card of Live TV, not an application that exited.
  return card ? (card.windowGroupOwnerId || card.appId) : '';
}

module.exports = { AfterExit, cardOf, isInput, isApp };
