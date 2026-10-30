const {test}=require('node:test');const assert=require('node:assert/strict');const fs=require('node:fs');const vm=require('node:vm');const {JSDOM}=require('jsdom');
const html=fs.readFileSync('index.html','utf8');
async function app(){
 const dom=new JSDOM(html.replace(/<script[\s\S]*?<\/script>/g,''),{url:'https://example.test/Rei-da-Faxina/',runScripts:'outside-only'});
 const w=dom.window;w.scrollTo=()=>{};w.matchMedia=()=>({matches:true});w.TextEncoder=TextEncoder;w.setInterval=()=>0;
 const calls=[];let authEvent;const sb={rpc:async(fn,args)=>{calls.push([fn,args]);return {data:fn==='public_status'?{hasAdmin:true,gameStart:'2026-11-01'}:fn==='sync_versions'?{settings:'1',profiles:'1'}:{ok:true}}},auth:{onAuthStateChange:f=>{authEvent=f},getSession:async()=>({data:{session:null}}),resetPasswordForEmail:async(...a)=>{calls.push(['reset',...a]);return {}},updateUser:async x=>{calls.push(['updateUser',x]);return {}},signOut:async()=>({})}};
 w.SUPABASE_CONFIG={url:'https://test.supabase.co',anonKey:'test'};w.supabase={createClient:(url,key,opts)=>{calls.push(['client',opts]);return sb}};
 const ctx=dom.getInternalVMContext();
 for(const f of ['faxinhos.js','pet.js'])vm.runInContext(fs.readFileSync(f,'utf8'),ctx,{filename:f});
 vm.runInContext(html.split('<script>')[1].split('</script>')[0],ctx,{filename:'index.html'});
 await new Promise(r=>setImmediate(r));return {dom,w,ctx,calls,event:e=>authEvent(e),sb};
}
test('recovery link request and recovery session render the reset form',async()=>{const a=await app();try{
 const c=a.w.__cj;c.H.begin();assert.ok([...a.w.document.querySelectorAll('button')].some(b=>b.textContent==='Esqueci minha senha'));
 c.H.forgot();assert.equal(a.w.document.querySelector('[role=dialog]').getAttribute('aria-labelledby'),'dialog-title');
 const fd=new a.w.FormData();fd.set('email','person@example.test');await c.F.forgot(fd);
 assert.equal(a.calls.find(x=>x[0]==='reset')[2].redirectTo,'https://example.test/Rei-da-Faxina/');
 a.event('PASSWORD_RECOVERY');await new Promise(r=>setTimeout(r,5));assert.ok(a.w.document.querySelector('[data-f=recoverpass]'));
 assert.equal(a.calls.find(x=>x[0]==='client')[1].auth.detectSessionInUrl,true);
}finally{a.dom.window.close()}});
test('modal traps Tab, closes on Escape, and restores trigger focus',async()=>{const a=await app();try{
 a.w.__cj.H.begin();const trigger=a.w.document.querySelector('[data-a=forgot]');trigger.focus();a.w.__cj.H.forgot();
 const buttons=a.w.document.querySelectorAll('#modal button');buttons[buttons.length-1].focus();a.w.document.dispatchEvent(new a.w.KeyboardEvent('keydown',{key:'Tab',bubbles:true,cancelable:true}));
 assert.equal(a.w.document.activeElement.name,'email');assert.equal(a.w.document.querySelector('#app').inert,true);
 a.w.document.dispatchEvent(new a.w.KeyboardEvent('keydown',{key:'Escape',bubbles:true}));assert.equal(a.w.document.activeElement,trigger);assert.equal(a.w.document.querySelector('#app').inert,false);
}finally{a.dom.window.close()}});
test('unsaved form survives refresh after blur',async()=>{const a=await app();try{
 a.w.__cj.H.begin();const e=a.w.document.querySelector('[name=email]');e.value='draft@example.test';e.dispatchEvent(new a.w.Event('input',{bubbles:true}));e.blur();
 a.w.__cj.Remote.draw(false);assert.equal(a.w.document.querySelector('[name=email]').value,'draft@example.test');assert.equal(a.w.__cj.Remote.dirty,true);
 a.w.__cj.Remote.draw(true);assert.equal(a.w.document.querySelector('[name=email]').value,'draft@example.test');
}finally{a.dom.window.close()}});
test('pet client sends only commands, never state or spend',async()=>{const a=await app();try{
 await a.w.__cj.A.petAction('buy','coroa');const c=a.calls.find(x=>x[0]==='pet_action');assert.deepEqual(Object.keys(c[1]).sort(),['p_action','p_key','p_value']);
 assert.equal(a.calls.some(x=>x[0]==='pet_save'),false);
}finally{a.dom.window.close()}});
test('service worker activation preserves other applications caches',async()=>{
 const callbacks={},deleted=[];const context={URL,Response,self:{addEventListener:(k,f)=>callbacks[k]=f,skipWaiting(){},clients:{claim:async()=>{}},registration:{scope:'https://example.test/Rei-da-Faxina/'}},caches:{keys:async()=>['foco-v9','other-app','rdf-v18','rei-da-faxina:v18','rei-da-faxina:v19'],delete:async k=>deleted.push(k)}};
 vm.runInNewContext(fs.readFileSync('sw.js','utf8'),context);let p;callbacks.activate({waitUntil:x=>p=x});await p;
 assert.deepEqual(deleted.sort(),['rdf-v18','rei-da-faxina:v18']);
});
test('idle polling does not reload tables and changed versions reload only affected data',async()=>{const a=await app();try{
 let versions={settings:'1',profiles:'1'};const reads=[];
 a.sb.rpc=async()=>({data:versions});a.sb.from=t=>({select:()=>({order:()=>({range:async()=>{reads.push(t);return {data:[]}}})})});
 await a.w.__cj.Remote.load();assert.equal(reads.length,17);reads.length=0;
 await a.w.__cj.Remote.load();assert.equal(reads.length,0);
 versions={...versions,profiles:'2'};await a.w.__cj.Remote.load();assert.deepEqual(reads,['profiles']);
}finally{a.dom.window.close()}});
test('lost pet response reuses request id on retry',async()=>{const a=await app();try{
 let keys=[];a.sb.rpc=async(name,args)=>{keys.push(args.p_key);if(keys.length===1)throw Error('connection lost');return {data:{ok:true}}};
 assert.equal((await a.w.__cj.A.petAction('buy','bola')).ok,false);
 assert.equal((await a.w.__cj.A.petAction('buy','bola')).ok,true);assert.equal(keys[0],keys[1]);
}finally{a.dom.window.close()}});
