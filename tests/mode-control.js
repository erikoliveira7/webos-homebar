const assert = require('assert');
const Mode = require('../webos10/helper/mode');
const base='/var/lib/webosbrew/rawin-launcher-home';
function fixture(release='10.3', current='legacy') {
  const files = {[base+'/mode-switch.sh']:'script', '/etc/starfish-release':'release '+release};
  if(current==='native')files[base+'/native-home']='';
  if(current==='overlay')files[base+'/additional-overlay']='';
  const fs={existsSync:p=>p in files,readFileSync:p=>{if(!(p in files))throw Error('missing');return files[p];},writeFileSync:(p,v)=>files[p]=v};
  const calls=[];let complete;
  const integration={inspect:()=>({nativeSupported:release.startsWith('10'),current,blockers:[],cleanup:0,owner:current==='native'?'native':'lg',fingerprint:'test'}),publicReport:r=>r};
  const mode=new Mode(fs,(cmd,args,opts,cb)=>{calls.push(args);complete=cb;},()=>{},integration);
  return {mode,files,calls,finish:err=>complete(err,'','test failure')};
}
for(const target of ['native','overlay']){
  const f=fixture();let replies=0;
  assert.deepStrictEqual(f.mode.start(target,()=>replies++),{ok:true,pending:true});
  assert.strictEqual(replies,1);assert.strictEqual(f.mode.status().busy,true);
  assert.strictEqual(f.mode.start(target,()=>{}).error,'busy');
  f.finish(null);assert.strictEqual(f.mode.status().busy,false);assert(f.mode.status().result.ok);
  assert.strictEqual(f.calls[0][1],target);
}
for(const current of ['native','overlay']){
  const f=fixture('10.3',current);assert.strictEqual(f.mode.start(current,()=>{throw Error('no response callback');}).pending,false);assert.strictEqual(f.calls.length,0);
}
{
 const f=fixture('6.3');assert(!f.mode.status().nativeSupported);
 assert.strictEqual(f.mode.start('native',()=>{}).error,'unsupported');assert(f.mode.start('overlay',()=>{}).ok);
}
{
 const f=fixture();assert.strictEqual(f.mode.start('evil;cmd',()=>{}).error,'invalid_mode');assert.strictEqual(f.calls.length,0);
 f.files[base+'/mode-switch-lock']='';assert.strictEqual(f.mode.start('native',()=>{}).error,'busy');
}
{
 const f=fixture();f.mode.start('native',()=>{});f.finish(Error('failed'));assert(!f.mode.status().result.ok);assert.strictEqual(f.mode.status().result.error,'launch_failed');assert.strictEqual(f.mode.status().result.detail,'test failure');
}
console.log('PASS mode API validation, no-op, concurrent requests, unsupported TV, durable result');
