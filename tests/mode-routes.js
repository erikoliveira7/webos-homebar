const fs=require('fs'),vm=require('vm'),assert=require('assert');
const source=fs.readFileSync('webos10/helper/service.js','utf8');
const modeRoute=source.slice(source.indexOf("    if (url.pathname === '/mode')"),source.indexOf("    if (url.pathname === '/restart'"));
const updateRoute=source.slice(source.indexOf("    if (url.pathname === '/update')"),source.indexOf("    if (url.pathname === '/backup'"));
async function request(route,changes={}){
 const replies=[],calls=[];
 const c=Object.assign({url:{pathname:'/mode'},req:{method:'POST',headers:{'content-type':'application/json'}},res:{},
  restarting:false,updateBusy:false,installingUpdate:()=>false,
  readBody:async()=>JSON.stringify({mode:'overlay',fingerprint:'a'.repeat(64)}),
  modeControl:{isBusy:()=>false,status:()=>({busy:false,current:'native'}),start:(m,before)=>{calls.push(m);before();return {ok:true,pending:true};}},
  preloader:{pause:()=>{}},send:(r,s,b)=>replies.push([s,b]),
  updateStep:async(step)=>{calls.push(step);return {ok:true};}},changes);
 await vm.runInNewContext('(async function(){'+route+'})()',c);
 assert.strictEqual(replies.length,1);return {replies,calls,c};
}
(async()=>{
 let r=await request(modeRoute,{req:{method:'POST',headers:{'content-type':'text/plain'}}});assert.strictEqual(r.replies[0][0],415);assert(!r.calls.length);
 r=await request(modeRoute,{readBody:async()=>JSON.stringify({mode:'native',fingerprint:''})});assert.strictEqual(r.replies[0][0],409);assert(!r.calls.length);
 r=await request(modeRoute);assert.deepStrictEqual(r.calls,['overlay']);assert.strictEqual(r.replies[0][0],200);
 for(const block of [{restarting:true},{updateBusy:true},{installingUpdate:()=>true}]){
  r=await request(modeRoute,block);assert.strictEqual(r.replies[0][0],409);assert.strictEqual(r.calls.length,0);
 }
 r=await request(modeRoute,{req:{method:'GET'}});assert.strictEqual(r.replies[0][1].current,'native');assert.strictEqual(r.calls.length,0);
 r=await request(modeRoute,{req:{method:'DELETE'}});assert.strictEqual(r.replies[0][0],405);
 r=await request(modeRoute,{modeControl:{start:()=>({ok:false,error:'invalid_mode'})}});assert.strictEqual(r.replies[0][0],409);
 for(const block of [{restarting:true},{updateBusy:true},{modeControl:{isBusy:()=>true}},{installingUpdate:()=>true}]){
  r=await request(updateRoute,Object.assign({url:{pathname:'/update'},query:{step:'install'}},block));assert.strictEqual(r.replies[0][0],409);assert.strictEqual(r.calls.length,0);
 }
 r=await request(updateRoute,{url:{pathname:'/update'},query:{step:'status'},installingUpdate:()=>true});assert.strictEqual(r.replies[0][0],200);assert.strictEqual(r.c.updateBusy,false);
 console.log('PASS actual mode/update routes: response before switch, methods, restart/update exclusion, update polling');
})();
