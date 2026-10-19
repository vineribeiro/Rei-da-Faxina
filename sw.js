const V='rdf-v11';
const SHELL=['./','index.html','config.js','pet.js','pet.css','manifest.webmanifest','icons/icon-192.png','icons/icon-512.png','img/logo.webp','img/av-menino.png','img/av-rainha.png','img/av-oculos.png','img/castelo.webp','img/i-raio.png','img/i-vassoura.png','img/i-spray.png','img/i-mop.png','img/i-golem.png','img/i-verme.png','img/i-aranha.png','img/i-serpente.png'];
self.addEventListener('install',e=>{e.waitUntil(caches.open(V).then(c=>c.addAll(SHELL)));self.skipWaiting()});
self.addEventListener('activate',e=>{e.waitUntil(caches.keys().then(k=>Promise.all(k.filter(x=>x!==V).map(x=>caches.delete(x)))).then(()=>self.clients.claim()))});
// Só guarda o próprio app e a biblioteca/fontes. Chamadas ao Supabase (dados e fotos privados) NUNCA entram no cache.
const OK_HOSTS=['cdn.jsdelivr.net','fonts.googleapis.com','fonts.gstatic.com'];
self.addEventListener('fetch',e=>{
  const r=e.request;if(r.method!=='GET')return;
  const u=new URL(r.url);
  if(u.origin!==location.origin&&!OK_HOSTS.includes(u.hostname))return;
  e.respondWith(fetch(r).then(res=>{if(res&&(res.ok||res.type==='opaque')){const cp=res.clone();caches.open(V).then(c=>c.put(r,cp))}return res})
    .catch(()=>caches.match(r).then(m=>m||(r.mode==='navigate'?caches.match('index.html'):undefined))));
});

self.addEventListener('notificationclick',e=>{e.notification.close();e.waitUntil(self.clients.matchAll({type:'window',includeUncontrolled:true}).then(l=>{for(const c of l){if('focus' in c){c.navigate&&c.navigate('./?go=pet').catch(()=>{});return c.focus()}}return self.clients.openWindow('./?go=pet')}))});
