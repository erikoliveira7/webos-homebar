const fs=require('fs'),vm=require('vm'),assert=require('assert');
const source=fs.readFileSync('webos10/helper/service.js','utf8');
const route=source.slice(source.indexOf("    if (url.pathname === '/launch-status')"),source.indexOf("    if (url.pathname === '/restart'"));
assert(!source.includes("url.pathname === '/mode'"));
for(const method of ['GET','POST']){
 const c={url:{pathname:'/launch-status'},req:{method},res:{},modeControl:{status:()=>({available:false,current:'native'})},send:(r,s,b)=>{c.status=s;c.body=b;}};
 vm.runInNewContext('(function(){'+route+'})()',c);
 assert.strictEqual(c.status,method==='GET'?200:405);if(method==='GET')assert.strictEqual(c.body.available,false);
}
const qml=fs.readFileSync('ui/Launcher.qml','utf8'),bridge=fs.readFileSync('webos10/panel-bridge.qml','utf8');
assert(!qml.includes('chooseMode'));assert(!qml.includes('set_mode'));assert(!bridge.includes('"/mode"'));assert(bridge.includes('/launch-status'));
console.log('PASS read-only launch status, no runtime mode endpoint/chooser, retained warnings');
