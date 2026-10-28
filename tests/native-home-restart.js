// Exercise the actual restart route: native Home cannot rely on closeByAppId.
const fs = require('fs'), vm = require('vm'), assert = require('assert');
const source = fs.readFileSync('webos10/helper/service.js','utf8');
const route = source.slice(source.indexOf("    if (url.pathname === '/restart'"),source.indexOf("    if (url.pathname === '/state'"));
async function check(native, error) {
    const timers=[],calls=[],execs=[],notes=[];
    const context={restarting:false,updateBusy:false,installingUpdate:()=>false,url:{pathname:'/restart'},req:{method:'POST'},res:{},
        modeControl:{isBusy:()=>false},nativeHomeMounted:()=>native,nativeHome:()=>native,panelId:()=>native?'com.webos.app.home':'org.rawin.launcher',
        preloader:{pause:()=>{}},send:()=>{},setTimeout:f=>timers.push(f),
        luna:(uri,p)=>calls.push([uri,p]),note:s=>notes.push(s),
        execFile:(cmd,args,done)=>{execs.push([cmd,args]);done(error?new Error('stop failed'):null);}};
    vm.runInNewContext('(function(){'+route+'})()',context);
    while(timers.length)timers.shift()();
    if(native){
        assert.strictEqual(execs.length,1);
        assert.strictEqual(execs[0][1][1],'stop');
        assert.strictEqual(calls.length,error?0:1);
        if(error)assert.strictEqual(notes.length,1);
        else assert.strictEqual(calls[0][1].id,'com.webos.app.home');
    }else{
        assert.strictEqual(execs.length,0);
        assert(calls[0][0].endsWith('/closeByAppId'));
        assert.strictEqual(calls[1][1].id,'org.rawin.launcher');
    }
}
(async()=>{await check(false,false);await check(true,false);await check(true,true);console.log('PASS native/regular restart and failed stop handling');})();
