const assert=require('assert'),fs=require('fs'),vm=require('vm');
const source=fs.readFileSync('webos10/helper/service.js','utf8');
const functions=source.slice(source.indexOf('function nativeHomeMounted()'),source.indexOf('const ICON_ROOTS'));
const route=source.slice(source.indexOf("    if (url.pathname === '/home')"),source.indexOf("    if (url.pathname === '/foreground')"));
for(const [configured,mounted,foreign] of [[false,false,false],[true,true,false],[true,false,true],[true,true,true]]){
 const ctx={modeControl:{foreignHome:()=>foreign},nativeHome:()=>configured,APP:'org.rawin.launcher',fs:{statSync:p=>({ino:p.includes('native-app')?(mounted?1:2):1,dev:1})},url:{pathname:'/home'},res:{},send:(r,s,b)=>ctx.answer=b};
 vm.runInNewContext(functions,ctx);vm.runInNewContext('(function(){'+route+'})()',ctx);
 assert.strictEqual(ctx.nativeHomeMounted(),configured&&mounted&&!foreign);
 assert.strictEqual(ctx.panelId(),configured&&mounted&&!foreign?'com.webos.app.home':'org.rawin.launcher');
 assert.strictEqual(ctx.answer.nativeHome,configured&&mounted&&!foreign);
 assert.strictEqual(ctx.answer.configuredNativeHome,configured);
}
console.log('PASS actual helper ownership: normal app stays accessible and restart avoids foreign Home after later takeover');

const wiring=source.slice(source.indexOf('const returner = new AfterExit'),source.indexOf('let subscribed = false;'));
for(const [native,mounted,companion,busy,foreign] of [[true,true,false,false,false],[true,false,false,false,true],[false,false,true,false,false],[true,true,false,true,false],[false,false,false,false,false]]) {
 const context={AfterExit:class {constructor(options){return options;}},savedInput:'',BASE:'/base',
 nativeHome:()=>native,nativeHomeMounted:()=>mounted,fs:{existsSync:()=>companion},modeControl:{isBusy:()=>busy,foreignHome:()=>foreign},glasshouseHome:()=>false,
 readSettings:()=>({exitTo:'com.webos.app.hdmi1'}),note:()=>{},luna:()=>Promise.resolve({}),LAST_INPUT_FILE:'/last'};
 vm.runInNewContext(wiring+';globalThis.options=returner;',context);
 assert.strictEqual(context.options.nativeHome(),mounted);
 assert.strictEqual(context.options.homeTaken(),(native&&!mounted)||companion||busy||foreign);
}
console.log('PASS native return wiring allows owned native Home only, respects companion/migration/foreign owner');
