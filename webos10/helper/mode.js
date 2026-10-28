// The setting is system state, not LocalStorage: both QML identities see it.
// A root shell owns migration and its rollback journal; this module serialises
// requests and keeps an error available when the requesting panel was closed.
'use strict';
// One copy of the module, webos10/integration.js: tools/build.py puts it next to
// this file in the package, in the source tree it is one folder up.
let Integration;
try { Integration = require('./integration'); } catch (e) { Integration = require('../integration'); }
const BASE = '/var/lib/webosbrew/rawin-launcher-home';
class ModeControl {
  constructor(fs, execFile, finished = () => {}, integration) {
    this.fs = fs; this.execFile = execFile; this.finished = finished; this.busy = false;
    this.integration = integration || new Integration({fs: fs});
  }
  foreignHome() { const owner = this.integration.ownership().owner; return owner === 'other' || owner === 'unknown'; }
  isBusy() { return this.busy || this.fs.existsSync(BASE + '/mode-switch-lock'); }
  status() {
    const exists = p => this.fs.existsSync(p);
    let result = null;
    try { result = JSON.parse(this.fs.readFileSync(BASE + '/mode-result.json', 'utf8')); } catch (e) {}
    const inspection = this.integration.inspect();
    return { inspection: this.integration.publicReport(inspection), migrationAvailable: inspection.migrationAvailable, available: exists(BASE + '/mode-switch.sh'),
      nativeSupported: inspection.nativeSupported,
      current: exists(BASE + '/native-home') ? 'native' : exists(BASE + '/additional-overlay') ? 'overlay' : 'legacy',
      busy: this.isBusy(), recoveryNeeded: !this.busy && exists(BASE + '/mode-switch-lock'), result: result };
  }
  start(mode, before, fingerprint) {
    const state = this.status();
    if (mode !== 'native' && mode !== 'overlay') return { ok: false, error: 'invalid_mode' };
    if (!state.available || (mode === 'native' && !state.nativeSupported)) return { ok: false, error: 'unsupported' };
    if (state.busy) return { ok: false, error: 'busy' };
    if (fingerprint && state.inspection.fingerprint !== fingerprint) return { ok: false, error: 'launch_changed' };
    if (mode === 'native' && state.inspection.blockers.length) return { ok: false, error: state.inspection.blockers[0].code };
    if (state.current === mode && !(mode === 'native' && (state.inspection.cleanup || state.inspection.owner === 'lg'))) return { ok: true, pending: false };
    this.busy = true;
    try {
      this.fs.writeFileSync(BASE + '/mode-result.json', JSON.stringify({ pending: true }));
    } catch (e) { this.busy = false; return { ok: false, error: 'journal_failed' }; }
    before();
    this.execFile('/bin/sh', [BASE + '/mode-switch.sh', mode, fingerprint || ''], { timeout: 120000 }, (err, stdout, stderr) => {
      const detail = err ? String(stderr || stdout || err.message).trim().slice(-1200) : '';
      const codes = detail.match(/launch_[a-z_]+/g);
      let restored = {};
      try { restored = JSON.parse(String(stdout || '').trim().split('\n').pop()); } catch (e) {}
      const result = { ok: !err, error: err ? (codes ? codes[codes.length-1] : 'launch_failed') : '', detail: detail, restoreSkipped: !!restored.restoreSkipped };
      try { this.fs.writeFileSync(BASE + '/mode-result.json', JSON.stringify(result)); } catch (e) {}
      this.busy = false;
      this.finished();
    });
    return { ok: true, pending: true };
  }
}
module.exports = ModeControl;
