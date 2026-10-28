// Loopback request guard: Host must be the loopback address and a request that
// changes something needs the panel's header (helper), the setup server's
// panel routes check the Host, and a failed /place write must not end the process.
const fs = require('fs'), vm = require('vm'), assert = require('assert'), http = require('http'), os = require('os'), path = require('path');
const guard = require('../shared/guard');
const req = (host, headers) => ({ headers: Object.assign(host === undefined ? {} : { host: host }, headers || {}) });
assert(guard.hostOk(req('127.0.0.1:8899'), 8899) && guard.hostOk(req('localhost:8899'), 8899) && guard.hostOk(req('[::1]:8899'), 8899));
for (const bad of ['evil.example', 'evil.example:8899', '127.0.0.1', '127.0.0.1:8898', '192.168.0.5:8899', '127.0.0.1:8899.evil.example', ''])
  assert(!guard.hostOk(req(bad), 8899), bad);
assert(!guard.hostOk(req(undefined), 8899) && !guard.hostOk({}, 8899));
assert(guard.marked(req('x', { 'x-homebar': '1' })) && !guard.marked(req('x', { 'x-homebar': '0' })) && !guard.marked(req('x')));

// The helper's own rule, taken from its source.
const source = fs.readFileSync(path.join(__dirname, '../webos10/helper/service.js'), 'utf8');
const changesState = vm.runInNewContext('(' + source.slice(source.indexOf('function changesState'), source.indexOf('const server = http.createServer')).trim().replace(/^function changesState/, 'function') + ')');
const url = (p, q) => ({ pathname: p, query: q || {} });
for (const p of ['/launch', '/close-apps', '/exit-target', '/restart', '/backup']) assert(changesState(url(p), { method: 'GET' }), p);
for (const step of ['check', 'download', 'install']) assert(changesState(url('/update', { step }), { method: 'GET' }), step);
assert(!changesState(url('/update', { step: 'status' }), { method: 'GET' }));
assert(changesState(url('/mode'), { method: 'POST' }) && !changesState(url('/mode'), { method: 'GET' }));
for (const p of ['/ping', '/apps', '/inputs', '/home', '/foreground', '/state', '/locale', '/restore']) assert(!changesState(url(p), { method: 'GET' }), p);
const handler = source.slice(source.indexOf('const server = http.createServer'));
assert(handler.indexOf('guard.hostOk') > 0 && handler.indexOf('guard.hostOk') < handler.indexOf("url.pathname === '/ping'"), 'host check comes before every route');
assert(handler.indexOf('guard.marked') < handler.indexOf("url.pathname === '/ping'"), 'header check comes before every route');
assert(/setRequestHeader\("X-Homebar", "1"\)/.test(fs.readFileSync(path.join(__dirname, '../webos10/panel-bridge.qml'), 'utf8')));

// The setup server for real, on its port, with a folder that is not there.
const setup = require('../shared/setup');
function call(method, p, headers, body) {
  return new Promise((resolve, reject) => {
    const r = http.request({ host: '127.0.0.1', port: setup.PORT, method, path: p, headers }, (res) => {
      const chunks = []; res.on('data', (c) => chunks.push(c)); res.on('end', () => resolve({ status: res.statusCode, body: Buffer.concat(chunks).toString() }));
    });
    r.on('error', reject); r.end(body);
  });
}
(async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'homebar-setup-'));
  const server = setup.start(path.join(dir, 'missing'));
  await new Promise((r) => setTimeout(r, 400));
  const own = { Host: '127.0.0.1:' + setup.PORT };
  let r = await call('GET', '/info', Object.assign({}, own));
  assert.strictEqual(r.status, 200);
  const token = JSON.parse(r.body).url.split('t=')[1];
  for (const host of ['evil.example', 'evil.example:' + setup.PORT, '192.168.0.5:' + setup.PORT]) {
    r = await call('GET', '/info', { Host: host }); assert.strictEqual(r.status, 404, host);
    r = await call('GET', '/weather', { Host: host }); assert.strictEqual(r.status, 404, host);
  }
  // The phone's page is served on the TV's LAN name, whatever it is.
  r = await call('GET', '/', { Host: '192.168.0.5:' + setup.PORT }); assert.strictEqual(r.status, 200);
  const place = JSON.stringify({ name: 'Gdansk', lat: 54.35, lon: 18.65 });
  r = await call('POST', '/place?t=' + token, { Host: '192.168.0.5:' + setup.PORT, 'Content-Length': place.length }, place);
  assert.strictEqual(r.status, 500, 'a failed write is an error answer');
  r = await call('GET', '/info', Object.assign({}, own)); assert.strictEqual(r.status, 200, 'the server is still there');
  r = await call('POST', '/place?t=wrong', { Host: '192.168.0.5:' + setup.PORT, 'Content-Length': place.length }, place); assert.strictEqual(r.status, 403);
  server.close(); fs.rmSync(dir, { recursive: true, force: true });
  console.log('PASS request guard: loopback Host, header for changes, setup server rejects foreign Host and survives a failed /place write');
  process.exit(0);
})().catch((e) => { console.error(e); process.exit(1); });
