const assert=require('assert');
const {AfterExit,cardOf}=require('../webos10/helper/after-exit');
let now=10000,foreign=false,native=true;
const launched=[],saved=[];
const r=new AfterExit({nativeHome:()=>native,homeTaken:()=>foreign,now:()=>now,
 lastInput:'com.webos.app.hdmi4',target:'com.webos.app.hdmi1',launch:id=>launched.push(id),save:id=>saved.push(id)});
r.onForeground('netflix');r.onForeground('com.webos.app.home');assert.deepStrictEqual(launched,[],'manual HOME must not redirect');
r.onForeground('netflix');r.onForeground('');assert.deepStrictEqual(launched,['com.webos.app.hdmi1'],'real app exit returns immediately');
r.onForeground('com.webos.app.home');r.onForeground('');assert.strictEqual(launched.length,1,'fallback repetitions must not return again');
now+=2000;r.setTarget('com.webos.app.livetv');r.onForeground('netflix');r.onForeground('');assert.strictEqual(launched[1],'com.webos.app.livetv');
now+=2000;r.setTarget('last');r.onForeground('com.webos.app.hdmi3');r.onForeground('netflix');r.onForeground('');assert.strictEqual(launched[2],'com.webos.app.hdmi3');
now+=2000;foreign=true;r.onForeground('netflix');r.onForeground('');assert.strictEqual(launched.length,3,'other launcher/mode owns return');
const child={appId:'com.webos.app.livedmost',windowType:'_WEBOS_WINDOW_TYPE_CARD',windowGroupOwner:false,windowGroupOwnerId:'com.webos.app.livetv'};
assert.strictEqual(cardOf({foregroundAppInfo:[child]}),'com.webos.app.livetv','TV child must resolve to owner');
assert.strictEqual(cardOf({foregroundAppInfo:[child,{appId:'com.webos.app.livetv',windowType:'_WEBOS_WINDOW_TYPE_CARD',windowGroupOwner:true}]}),'com.webos.app.livetv');
foreign=false;native=false;now+=2000;r.onForeground('com.webos.app.home');assert.strictEqual(launched.length,4,'legacy overlay Home fallback retained');
console.log('PASS native exit return: manual HOME safe, app exit, duplicate fallback, fixed HDMI/TV/last, foreign owner and Live TV group');
