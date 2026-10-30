const PREFIX='rei-da-faxina:';
const V=PREFIX+'v19';
const SHELL=['./','index.html','config.js','pet.js','faxinhos.js','pet.css','ui.css','fonts/press-start-2p.woff2','fonts/vt323.woff2','manifest.webmanifest','img/logo-title.png','img/castelo-noite.png','img/lua.png','img/nuvem.png','img/grama-borda.png','icons/icon-192.png','icons/icon-512.png','img/logo.webp','img/av-menino.png','img/av-rainha.png','img/av-oculos.png','img/rei-idle.png','img/rei.png','img/trono.png','img/estante.png','img/tile-marmore.webp','img/tile-tapete.webp','img/tile-sujo.webp','img/coin.png','img/ui-heart-full.png','img/ui-heart-empty.png','img/ui-bolt-full.png','img/ui-bolt-empty.png','img/crown-2.png','img/crown-3.png','img/it-vassoura.png','img/it-mop.png','img/it-spray.png','img/it-balde.png','img/m-golem-idle.png','img/m-golem-attack.png','img/m-golem-hit.png','img/m-golem-death.png','img/m-verme-idle.png','img/m-verme-attack.png','img/m-verme-hit.png','img/m-verme-death.png','img/m-aranha-idle.png','img/m-aranha-attack.png','img/m-aranha-hit.png','img/m-aranha-death.png','img/m-cobra-idle.png','img/m-cobra-attack.png','img/m-cobra-hit.png','img/m-cobra-death.png'];
self.addEventListener('install',e=>{e.waitUntil(caches.open(V).then(c=>c.addAll(SHELL)));self.skipWaiting()});
self.addEventListener('activate',e=>{e.waitUntil(caches.keys().then(k=>Promise.all(k.filter(x=>(x.startsWith(PREFIX)||/^rdf-v\d+$/.test(x))&&x!==V).map(x=>caches.delete(x)))).then(()=>self.clients.claim()))});
// Só guarda o próprio app e a biblioteca/fontes. Chamadas ao Supabase (dados e fotos privados) NUNCA entram no cache.
const OK_HOSTS=['cdn.jsdelivr.net','fonts.googleapis.com','fonts.gstatic.com'];
self.addEventListener('fetch',e=>{
  const r=e.request;if(r.method!=='GET')return;
  const u=new URL(r.url);
  if(u.origin===location.origin&&!u.pathname.startsWith(new URL(self.registration.scope).pathname))return;
  if(u.origin!==location.origin&&!OK_HOSTS.includes(u.hostname))return;
  e.respondWith(fetch(r).then(res=>{if(res&&(res.ok||res.type==='opaque')){const cp=res.clone();caches.open(V).then(c=>c.put(r,cp))}return res})
    .catch(()=>caches.open(V).then(c=>c.match(r).then(m=>m||(r.mode==='navigate'?c.match('index.html'):Response.error())))));
});

self.addEventListener('notificationclick',e=>{e.notification.close();e.waitUntil(self.clients.matchAll({type:'window',includeUncontrolled:true}).then(l=>{for(const c of l){if('focus' in c){c.navigate&&c.navigate('./?go=pet').catch(()=>{});return c.focus()}}return self.clients.openWindow('./?go=pet')}))});
