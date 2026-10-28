// Read-only launch ownership and interrupted installation state. Runtime mode
// switching is deferred; only the installer can start a native migration.
'use strict';
const Integration = require('./integration');
const BASE = '/var/lib/webosbrew/rawin-launcher-home';
class ModeControl {
  constructor(fs, integration) {
    this.fs = fs; this.busy = false;
    this.integration = integration || new Integration({fs: fs});
  }
  foreignHome() { const owner = this.integration.ownership().owner; return owner === 'other' || owner === 'unknown'; }
  isBusy() { return this.busy || this.fs.existsSync(BASE + '/mode-switch-lock'); }
  status() {
    const exists = p => this.fs.existsSync(p);
    let result = null;
    try { result = JSON.parse(this.fs.readFileSync(BASE + '/mode-result.json', 'utf8')); } catch (e) {}
    const inspection = this.integration.inspect();
    return { inspection: this.integration.publicReport(inspection), migrationAvailable: inspection.migrationAvailable, available: false,
      nativeSupported: inspection.nativeSupported,
      current: exists(BASE + '/native-home') ? 'native' : exists(BASE + '/additional-overlay') ? 'overlay' : 'legacy',
      busy: this.isBusy(), recoveryNeeded: !this.busy && exists(BASE + '/mode-switch-lock'), result: result };
  }
}
module.exports = ModeControl;
