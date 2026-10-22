/* ===== Faxinhos: bichinho estilo Tamagotchi =====
   Motor (tempo real, calculado ao abrir), tela, ações pagas com moedas e avisos.
   Carregado antes do script principal; usa as globais dele (S, UI, A, balance, wallet...) só em tempo de execução. */
const HR=3600e3,DAY=24*HR;
const PET_SPECIES=[
 {id:'dragao',n:'Dragãozinho Brasa',e:'🐲',r:'lendário',pref:15,sleep:[22,7],bio:'Adora calor. Sente frio de madrugada e solta fumacinha quando está feliz.'},
 {id:'unicornio',n:'Unicórnio Aurora',e:'🦄',r:'lendário',pref:0,sleep:[22,7],bio:'Delicado e exigente. Brilha mais quando é bem cuidado.'},
 {id:'coruja',n:'Coruja Lunar',e:'🦉',r:'raro',pref:-4,sleep:[7,16],bio:'Dorme de dia e acorda à noite. Observa tudo em silêncio.'},
 {id:'raposa',n:'Raposa Ruiva',e:'🦊',r:'raro',pref:3,sleep:[22,7],bio:'Esperta e curiosa. Enjoa rápido das mesmas brincadeiras.',m:{fun:1.2}},
 {id:'polvo',n:'Polvo Marujo',e:'🐙',r:'raro',pref:-6,sleep:[22,7],bio:'Vive com sede. Tem oito braços e nenhum deles segura copo.',m:{thirst:1.4}},
 {id:'morcego',n:'Morcego Noturno',e:'🦇',r:'raro',pref:-8,sleep:[8,17],bio:'Prefere o escuro e o fresquinho. Dorme de cabeça para baixo.'},
 {id:'pinguim',n:'Pinguim Gelado',e:'🐧',r:'comum',pref:-15,sleep:[22,7],bio:'Ama o frio. Derrete de calor à tarde.'},
 {id:'lagarto',n:'Lagartixa Solar',e:'🦎',r:'comum',pref:12,sleep:[21,6],bio:'Vive de sol. À noite fica bem friorenta.'},
 {id:'panda',n:'Panda Soneca',e:'🐼',r:'comum',pref:-3,sleep:[21,8],bio:'Cansa fácil e adora um cochilo.',m:{energy:1.4}},
 {id:'coelho',n:'Coelho Pulinho',e:'🐰',r:'comum',pref:0,sleep:[22,7],bio:'Agitado. Fica entediado muito rápido.',m:{fun:1.4}}];
const PET_STAGES=[['baby','Bebê','🍼',0,1.4],['child','Criança','🎈',2,1.15],['teen','Jovem','🎒',6,1],['adult','Adulto','⭐',13,.9],['senior','Veterano','🏅',27,.9],['elder','Ancião','🧓',48,1.1]];
const PET_LIFE_DAYS=62,PET_REVIVE_H=72;
const PET_SHOP=[
 {id:'casinha',e:'🏠',n:'Casinha',cost:60,d:'Segura o frio e o calor: a temperatura varia pela metade.'},
 {id:'bola',e:'⚽',n:'Bola',cost:15,d:'Brincar rende mais diversão.'},
 {id:'cama',e:'🛏️',n:'Caminha macia',cost:40,d:'Dormir recupera mais energia.'},
 {id:'laco',e:'🎀',n:'Laço',cost:12,cos:'top'},{id:'oculos',e:'🕶️',n:'Óculos escuros',cost:20,cos:'mid'},
 {id:'cartola',e:'🎩',n:'Cartola',cost:30,cos:'top'},{id:'cachecol',e:'🧣',n:'Cachecol',cost:25,cos:'bot'},{id:'coroa',e:'👑',n:'Coroa real',cost:80,cos:'top'}];
const spec=id=>PET_SPECIES.find(s=>s.id===id);
const rnd=(seed,n)=>{const x=Math.sin(seed*12.9898+n*78.233)*43758.5453;return x-Math.floor(x)};
const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
const NEEDS=['hunger','thirst','fun','energy','hygiene','love'];
const inSleep=(h,[a,b])=>a>b?(h>=a||h<b):(h>=a&&h<b);
const stageOf=age=>{let s=PET_STAGES[0];for(const x of PET_STAGES)if(age>=x[3])s=x;return s};

function newEgg(bonus){return {seed:Math.floor(Math.random()*1e6)+1,stage:'egg',species:null,name:'',named:false,bornAt:Date.now(),t:Date.now(),warm:0,bonus:!!bonus,cd:{},low:{},mistakes:0,
  hunger:90,thirst:90,fun:90,energy:90,hygiene:100,love:80,temp:50,health:100,sick:false,pf:0,digest:0,buff:null,form:null,dead:null,retired:null,hatchedAt:null}}
function pickSpecies(seed,bonus){
  const r=rnd(seed,7),pl=.10+(bonus?.08:0),pr=.35+(bonus?.12:0);
  const rar=r<pl?'lendário':r<pl+pr?'raro':'comum',pool=PET_SPECIES.filter(s=>s.r===rar);
  return pool[Math.floor(rnd(seed,11)*pool.length)%pool.length];
}
/* Avança o bichinho no tempo. Puro: devolve uma cópia. */
function petTick(src,now,own){
  const st=JSON.parse(JSON.stringify(src));own=own||[];
  if(st.dead||st.retired){st.t=now;return st}
  if(st.stage==='egg'&&st.warm>=100)petHatch(st,now);
  let t=Math.max(st.t,now-45*DAY);const step=.5*HR;
  while(t<now){
    const dt=Math.min(step,now-t)/HR;t+=dt*HR;
    if(st.stage==='egg'){st.warm=Math.min(100,st.warm+.5*dt);if(st.warm>=100){petHatch(st,t)}continue}
    const sp=spec(st.species),d=new Date(t),hr=d.getHours()+d.getMinutes()/60,sleeping=inSleep(Math.floor(hr),sp.sleep),m=sp.m||{};
    const age=(t-st.hatchedAt)/DAY;
    if(age>=PET_LIFE_DAYS){st.retired=t;st.stage='retired';break}
    const sg=stageOf(age);if(st.stage!==sg[0]){st.stage=sg[0];if(sg[0]==='adult'&&!st.form)st.form=st.mistakes<=3?'radiante':st.mistakes<=10?'normal':'rebelde'}
    const mult=sg[4],sm=sleeping?.35:1;
    st.hunger-=2.6*mult*sm*dt;st.thirst-=3.2*(m.thirst||1)*mult*sm*dt;st.fun-=2.4*(m.fun||1)*mult*sm*dt;
    st.energy=sleeping?st.energy+9*(own.includes('cama')?1.4:1)*dt:st.energy-2*(m.energy||1)*mult*dt;
    st.hygiene-=(1.2+3*Math.floor(st.pf))*sm*dt;st.love-=1.4*(sleeping?.3:1)*dt;
    const dg=Math.min(st.digest,15*dt);st.digest-=dg;st.pf+=dg/50;
    NEEDS.forEach(k=>st[k]=clamp(st[k],0,100));
    let amb=50+28*Math.sin((hr-9)/24*2*Math.PI),tg=amb-sp.pref;
    if(st.buff&&t<st.buff.until)tg+=st.buff.v;
    if(own.includes('casinha'))tg=50+(tg-50)*.5;
    st.temp=clamp(st.temp+(tg-st.temp)*(1-Math.exp(-.5*dt)),0,100);
    const dev=Math.abs(st.temp-50);
    const conds={hunger:st.hunger<=12,thirst:st.thirst<=12,fun:st.fun<=12,energy:!sleeping&&st.energy<=12,hygiene:st.hygiene<=12||st.pf>=3,love:st.love<=12,temp:dev>35};
    let crit=0;if(st.hunger<=8)crit++;if(st.thirst<=8)crit++;if(dev>38)crit++;if(!sleeping&&st.energy<=8)crit++;if(st.pf>=4||st.hygiene<=8)crit++;
    for(const k in conds){
      const v=st.low[k]||0;
      if(v<0){st.low[k]=Math.min(0,v+dt*60);continue}
      if(conds[k]&&!sleeping){st.low[k]=v+dt*60;if(st.low[k]>=120){st.mistakes++;st.low[k]=-180}}else st.low[k]=0;
    }
    if(!st.sick){
      const r=.003+(st.hygiene<20?.04:0)+(st.pf>=3?.05:0)+(dev>38?.05:0)+(st.health<40?.03:0);
      if(rnd(st.seed,Math.floor(t/step))<r*dt*2){st.sick=true;st.sickAt=t}
    }
    st.health+=(st.sick?-3:(crit?-.6*crit:2))*dt;st.health=clamp(st.health,0,100);
    if(st.health<=0){st.dead=t;break}
  }
  st.t=now;return st;
}
function petHatch(st,t){const sp=pickSpecies(st.seed,st.bonus);Object.assign(st,{stage:'baby',species:sp.id,hatchedAt:t,t:t,hunger:85,thirst:85,fun:85,energy:90,hygiene:100,love:90,temp:50,health:100});if(!st.name)st.name=sp.n}
const petMood=(st,now)=>{
  if(!st)return null;if(st.dead)return {e:'😵',t:'Partiu...',sev:2};if(st.retired)return {e:'🌟',t:'Seguiu para o Jardim das Estrelas.',sev:0};
  if(st.stage==='egg')return {e:'🥚',t:st.warm>=70?'Está mexendo aí dentro!':'Quentinho e quieto...',sev:0};
  const sp=spec(st.species),sl=inSleep(new Date(now).getHours(),sp.sleep);
  if(st.sick)return {e:'🤒',t:'Não estou me sentindo bem...',sev:2,k:'sick'};
  if(sl)return {e:'😴',t:'Zzz...',sev:0};
  if(st.temp<=20||st.temp>=80)return {e:st.temp<50?'🥶':'🥵',t:st.temp<50?'Estou congelando!':'Estou fervendo!',sev:2,k:'temp'};
  if(st.hunger<=25)return {e:'😫',t:'Estou com fome!',sev:st.hunger<=10?2:1,k:'hunger'};
  if(st.thirst<=25)return {e:'🥤',t:'Estou com sede!',sev:st.thirst<=10?2:1,k:'thirst'};
  if(st.temp<=32||st.temp>=68)return {e:st.temp<50?'🥶':'🥵',t:st.temp<50?'Estou com frio.':'Estou com calor.',sev:1,k:'temp'};
  if(st.pf>=2||st.hygiene<=20)return {e:'🤢',t:'Aqui está sujo...',sev:1,k:'hygiene'};
  if(st.fun<=25)return {e:'😐',t:'Estou entediado...',sev:1,k:'fun'};
  if(st.energy<=18)return {e:'😪',t:'Estou cansado.',sev:1,k:'energy'};
  if(st.love<=25)return {e:'🥺',t:'Quero carinho.',sev:1,k:'love'};
  return {e:'😊',t:['Tudo certo por aqui!','Que dia bom!','Gosto de você.','Vamos brincar?'][Math.floor(now/DAY+st.seed)%4],sev:0};
};
/* ---- estado salvo ---- */
const petGet=()=>(S.pets||{})[UI.me]||null;
const petOwn=P=>(P&&P.own)||[];
const petCur=P=>P&&P.cur?petTick(P.cur,Date.now(),petOwn(P)):null;
async function petPersist(P,spend,reason){
  const r=await A.petSave(UI.me,P,spend||0,reason||'');
  if(r&&r.ok&&!REMOTE){/* local: já gravado */}
  return r;
}
/* ---- ações ---- */
const up=(v,n)=>clamp(v+n,0,100);
const PET_ACT={
 racao:{cost:6,msg:'Nham! Ração boa.',run:s=>{if(s.hunger>=92)return 'Está de barriguinha cheia.';s.hunger=up(s.hunger,30);s.digest+=30}},
 fruta:{cost:3,msg:'Fruta fresquinha!',run:s=>{if(s.hunger>=92)return 'Está de barriguinha cheia.';s.hunger=up(s.hunger,16);s.love=up(s.love,3);s.digest+=14}},
 banquete:{cost:14,msg:'Que banquete!',run:s=>{if(s.hunger>=85)return 'Sem espaço para um banquete agora.';s.hunger=up(s.hunger,50);s.fun=up(s.fun,12);s.digest+=60}},
 agua:{cost:0,msg:'Glub glub!',run:s=>{if(s.thirst>=92)return 'Já bebeu o suficiente.';s.thirst=up(s.thirst,40)}},
 brincar:{cost:0,cd:20,msg:'Que divertido!',run:(s,P)=>{if(s.energy<15)return 'Está cansado demais para brincar.';s.fun=up(s.fun,petOwn(P).includes('bola')?35:20);s.energy=up(s.energy,-8);s.hunger=up(s.hunger,-3)}},
 passear:{cost:2,cd:60,msg:'Passeio ótimo!',run:s=>{if(s.energy<25)return 'Está cansado demais para passear.';s.fun=up(s.fun,30);s.love=up(s.love,8);s.energy=up(s.energy,-15);s.hygiene=up(s.hygiene,-8)}},
 carinho:{cost:0,cd:15,msg:'Ronrom de felicidade.',run:s=>{s.love=up(s.love,12);s.fun=up(s.fun,3)}},
 banho:{cost:1,cd:120,msg:'Cheirosinho!',run:s=>{s.hygiene=up(s.hygiene,50);s.pf=0}},
 limpar:{cost:0,msg:'Limpinho!',run:s=>{if(s.pf<1)return 'Não tem nada para limpar.';s.pf=0;s.hygiene=up(s.hygiene,10)}},
 cobertor:{cost:6,msg:'Quentinho!',run:s=>{s.temp=up(s.temp,15);s.buff={v:20,until:Date.now()+6*HR}},ok:true},
 gelo:{cost:6,msg:'Refrescante!',run:s=>{s.temp=up(s.temp,-15);s.buff={v:-20,until:Date.now()+4*HR}},ok:true},
 remedio:{cost:15,msg:'Remédio dado. Já está melhorando.',run:s=>{if(!s.sick)return 'Não está doente.';s.sick=false;s.health=up(s.health,15)},ok:true}
};
const PET_LABEL={racao:'Ração',fruta:'Fruta',banquete:'Banquete',agua:'Água',brincar:'Brincar',passear:'Passear',carinho:'Carinho',banho:'Banho',limpar:'Limpar',cobertor:'Cobertor',gelo:'Gelo',remedio:'Remédio'};
const PET_ICON={racao:'🍖',fruta:'🍎',banquete:'🍰',agua:'💧',brincar:'🎾',passear:'🌳',carinho:'💗',banho:'🛁',limpar:'🧹',cobertor:'🧣',gelo:'🧊',remedio:'💊'};
async function petDo(id){
  const P=petGet(),me=UI.me;if(!P||!P.cur)return;const now=Date.now(),def=PET_ACT[id];
  const s=petTick(P.cur,now,petOwn(P));
  if(s.stage==='egg'||s.dead||s.retired)return;
  if(inSleep(new Date(now).getHours(),spec(s.species).sleep)&&!def.ok&&id!=='limpar')return toast('Shhh... está dormindo. Volte mais tarde.','err');
  const cd=(def.cd||0)*60000,last=(s.cd||{})[id]||0;
  if(cd&&now-last<cd)return toast('Calma! Tente de novo em '+Math.ceil((cd-(now-last))/60000)+' min.','err');
  if(def.cost>balance(me))return toast('Moedas insuficientes. Cumpra missões para ganhar mais.','err');
  const e=def.run(s,P);if(e)return toast(e,'err');
  if(cd){s.cd=s.cd||{};s.cd[id]=now}
  const r=await petPersist(Object.assign({},P,{cur:s}),def.cost,PET_LABEL[id]+' para '+(s.name||'o Faxinho'));
  if(r&&r.ok){toast(def.msg,'ok');if(!REMOTE)render()}else if(r)toast(r.err,'err');
}
const PET_H={
 pget:async()=>{const P=petGet()||{own:[],album:{},wear:null};P.cur=newEgg(!!P.legacy);P.legacy=null;const r=await petPersist(P,0,'');if(r.ok){toast('Você ganhou um ovo misterioso!','star');if(!REMOTE)render()}else toast(r.err,'err')},
 pegg:async()=>{const P=petGet();if(!P)return;if(20>balance(UI.me))return toast('Um ovo novo custa 20 moedas.','err');P.cur=newEgg(!!P.legacy);P.legacy=null;const r=await petPersist(P,20,'Novo ovo misterioso');if(r.ok){toast('Novo ovo misterioso!','star');if(!REMOTE)render()}else toast(r.err,'err')},
 pwarm:async()=>{const P=petGet(),now=Date.now();if(!P||!P.cur)return;const s=petTick(P.cur,now,petOwn(P));if(s.stage!=='egg')return;
   if(now-((s.cd||{}).warm||0)<15*60000)return toast('O ovo já está quentinho. Volte em alguns minutos.','err');
   s.cd=s.cd||{};s.cd.warm=now;s.warm=Math.min(100,s.warm+10);
   const r=await petPersist(Object.assign({},P,{cur:s}),0,'');if(r.ok){if(s.warm<100)toast('Aquecendo o ovo...','ok');if(!REMOTE)render()}},
 pact:async d=>petDo(d.k),
 previve:async()=>{const P=petGet();if(!P||!P.cur||!P.cur.dead)return;if(40>balance(UI.me))return toast('A Poção da Fênix custa 40 moedas.','err');
   const s=JSON.parse(JSON.stringify(P.cur));Object.assign(s,{dead:null,health:40,hunger:50,thirst:50,fun:50,energy:60,hygiene:60,love:50,temp:50,sick:false,pf:0,t:Date.now(),low:{}});s.mistakes+=3;
   const r=await petPersist(Object.assign({},P,{cur:s}),40,'Poção da Fênix');if(r.ok){toast('Ele voltou!','star');confetti(30);if(!REMOTE)render()}else toast(r.err,'err')},
 pbuy:async d=>{const P=petGet();if(!P||!P.cur)return;const it=PET_SHOP.find(x=>x.id===d.k);if(!it||petOwn(P).includes(it.id))return;
   if(it.cost>balance(UI.me))return toast('Moedas insuficientes.','err');
   const P2=Object.assign({},P,{own:[...petOwn(P),it.id]});if(it.cos)P2.wear=it.id;
   const r=await petPersist(P2,it.cost,'Item: '+it.n);if(r.ok){toast(it.n+' comprado!','star');if(!REMOTE)render()}else toast(r.err,'err')},
 pwear:async d=>{const P=petGet();if(!P)return;const P2=Object.assign({},P,{wear:P.wear===d.k?null:d.k});const r=await petPersist(P2,0,'');if(r.ok&&!REMOTE)render()},
 pname:()=>{const P=petGet();if(!P||!P.cur)return;openModal('<h2>Dar um nome</h2><form class="col" data-f="pname"><label class="f">Nome<input class="in" name="n" maxlength="16" minlength="2" required autofocus value="'+esc(P.cur.named?P.cur.name:'')+'"></label><div class="row"><button class="btn primary" type="submit">Salvar</button><button class="btn ghost" type="button" data-a="close">Cancelar</button></div></form>')},
 pnotif:async()=>{
   if(!('Notification' in window))return toast('Este navegador não oferece avisos.','err');
   if(LS.get('rdf:pnon')==='1'){LS.set('rdf:pnon','0');render();return}
   let p=Notification.permission;if(p==='default')p=await Notification.requestPermission();
   if(p!=='granted')return toast('Os avisos foram bloqueados. Libere nas configurações do navegador.','err');
   LS.set('rdf:pnon','1');toast('Avisos ligados!','ok');petNotify('Avisos ligados','Eu aviso quando precisar de você.','teste');render()}
};
const PET_F={pname:async fd=>{const n=String(fd.get('n')||'').trim().slice(0,16);if(n.length<2)return toast('Use pelo menos 2 letras.','err');const P=petGet();if(!P||!P.cur)return;
  const s=JSON.parse(JSON.stringify(P.cur));s.name=n;s.named=true;closeModal();const r=await petPersist(Object.assign({},P,{cur:s}),0,'');if(r.ok&&!REMOTE)render()}};
/* ---- eventos: chocar, partir, aposentar ---- */
async function petCheck(){
  if(UI.pbusy||!UI.me||!S.pets)return;const P=petGet();if(!P||!P.cur)return;const was=P.cur,s=petCur(P);
  const hatched=was.stage==='egg'&&s.stage!=='egg',died=!was.dead&&s.dead,retired=!was.retired&&s.retired;
  if(!hatched&&!died&&!retired)return;
  UI.pbusy=true;
  try{
    const P2=Object.assign({},P,{cur:s,album:Object.assign({},P.album)});
    if(hatched){const sp=spec(s.species),a=P2.album[sp.id]||{n:0,best:0};P2.album[sp.id]={n:a.n+1,best:a.best};
      sfx('win');confetti(40);vibrate([100,50,100]);
      openModal('<div class="tut col"><div class="pegg-big">'+petSpr(sp.id,{px:8,mood:'happy',stage:'teen',cls:'hop'})+'</div><h2>Chocou!</h2><p>Era um <strong>'+esc(sp.n)+'</strong>.<br><span class="pill">'+sp.r+'</span></p><p class="sm muted">'+esc(sp.bio)+'</p><div class="row" style="justify-content:center"><button class="btn primary" data-a="pname">Dar um nome</button><button class="btn ghost" data-a="close">Depois</button></div></div>')}
    if(retired){const sp=spec(s.species),a=P2.album[sp.id]||{n:1,best:0};P2.album[sp.id]={n:a.n,best:Math.max(a.best,PET_LIFE_DAYS),form:s.form};P2.legacy=sp.id;
      sfx('win');confetti(50);openModal('<div class="tut col"><div class="pegg-big">'+petSpr(sp.id,{px:8,mood:'happy',stage:'teen',cls:'hop'})+'</div><h2>Uma vida inteira</h2><p>'+esc(s.name||sp.n)+' viveu '+PET_LIFE_DAYS+' dias com você e seguiu para o Jardim das Estrelas.</p><p class="sm muted">Ele deixou um ovo de presente, com mais chance de raridade.</p><button class="btn primary" data-a="close">Receber o ovo</button></div>');
      P2.cur=newEgg(true)}
    if(died){sfx('err');vibrate([200,100,200]);openModal('<div class="tut col"><div class="pegg-big">'+petSpr(s.species,{px:8,mood:'dead',stage:s.stage})+'</div><h2>'+esc(s.name||'O Faxinho')+' partiu</h2><p>Faltou cuidado por muito tempo. Dá para reviver com a Poção da Fênix em até '+PET_REVIVE_H+' horas.</p><button class="btn primary" data-a="close">Entendi</button></div>')}
    await petPersist(P2,0,'');
  }finally{UI.pbusy=false}
}
/* ---- tela: sprites 8 bits de faxinhos.js ---- */
const FX_PX={baby:5,child:6,teen:7,adult:7,senior:7,elder:6};
const PET_ACTICON={racao:'racao',fruta:'fruta',banquete:'banquete',agua:'agua',brincar:'bola',passear:'arvore',carinho:'carinho',banho:'banho',limpar:'vassoura',cobertor:'cobertor',gelo:'gelo',remedio:'remedio'};
function petFace(st,now){
  const m=petMood(st,now);let mood='happy',cold=false,hot=false,icons=[];
  if(st.dead)mood='dead';
  else{
    const sl=inSleep(new Date(now).getHours(),spec(st.species).sleep);
    if(sl){mood='sleep';icons.push(['zz',18,1])}
    else if(st.sick){mood='sick';icons.push(['plus',19,2])}
    else switch(m.k){
      case 'hunger':mood='hungry';break;
      case 'thirst':mood='sad';icons.push(['drop',19,2]);break;
      case 'temp':if(st.temp<50){cold=true;mood='sad';icons.push(['snow',18,1])}else{hot=true;mood='bored';icons.push(['drop',19,2])}break;
      case 'hygiene':mood='sad';icons.push(['stink',18,1]);break;
      case 'fun':case 'energy':mood='bored';break;
      case 'love':mood='sad';icons.push(['heart',19,2]);break;
    }
    if(!icons.length&&st.form==='radiante')icons=[['spark',1,2],['spark',20,3],['spark',2,19]];
  }
  return {mood,cold,hot,icons};
}
const petSpr=(sid,o)=>fxSprite(sid,o);
function petBar(icon,label,v,temp){
  const c=temp?(Math.abs(v-50)<=18?'var(--green)':Math.abs(v-50)<=30?'var(--yellow)':'var(--red)'):(v>50?'var(--green)':v>25?'var(--yellow)':'var(--red)');
  const lab=temp?(v<35?'Frio':v>65?'Calor':'Agradável'):Math.round(v)+'%';
  return '<div class="pv"><span class="pl">'+icon+'<span>'+label+'</span></span><div class="bar" role="progressbar" aria-label="'+label+'" aria-valuemin="0" aria-valuemax="100" aria-valuenow="'+Math.round(v)+'"><i style="width:'+Math.round(v)+'%;background:'+c+'"></i></div><span class="pn">'+lab+'</span></div>';
}
function petSprite(st,P,now){
  const hr=new Date(now).getHours(),night=hr<6||hr>=19,own=petOwn(P);
  const win='<div class="win"><div class="wsky">'+(night?pxi('lua',4,'moon')+'<i class="st s1"></i><i class="st s2"></i><i class="st s3"></i>':pxi('sol',4,'sun')+pxi('nuvem',3,'cl'))+'</div></div>';
  const props=(own.includes('casinha')?'<div class="prop casa">'+pxi('casinha',5)+'</div>':'')+(own.includes('cama')?'<div class="prop cama">'+pxi('caminha',4)+'</div>':'')+(own.includes('bola')?'<div class="prop bola">'+pxi('bola',3)+'</div>':'');
  let body,cls='';
  if(st.stage==='egg'){body=fxEgg(st.seed,st.warm,8);cls=st.warm>=70?'shake':'bob'}
  else{
    const f=petFace(st,now);
    body=petSpr(st.species,{mood:f.mood,stage:st.stage,wear:P.wear,form:st.form,cold:f.cold,hot:f.hot,icons:f.icons,px:FX_PX[st.stage]||6});
    cls=(f.mood==='sleep'?'sleep':f.mood==='dead'?'dead':f.cold?'shiver':'bob')+(st.form==='radiante'&&!st.dead?' glow':'');
  }
  const hearts=st.stage!=='egg'&&!st.dead&&st.love>85&&st.hunger>40?'<span class="fh h1">'+pxi('carinho',3)+'</span><span class="fh h2">'+pxi('carinho',2)+'</span>':'';
  const poops=st.stage==='egg'?'':'<div class="poops" aria-label="'+Math.floor(st.pf)+' sujeira(s)">'+Array.from({length:Math.min(4,Math.floor(st.pf))},()=>pxi('poop',4)).join('')+'</div>';
  return '<div class="room '+(night?'night':'day')+'"><div class="wallp"></div>'+win+'<div class="floor2"></div><div class="rug"></div>'+props+'<div class="pet '+cls+'">'+body+hearts+'</div>'+poops+'</div>';
}
function vPet(){
  const me=user(UI.me);
  if(!plays(me))return '<div class="card">'+empty('🥚','Administradores não criam bichinho','Quem joga cuida do próprio Faxinho. O administrador só organiza a casa.')+'</div>';
  if(REMOTE&&Remote.petsOk===false)return '<div class="card">'+empty('🛠️','Falta atualizar o banco','O administrador precisa rodar o arquivo supabase/pets.sql no SQL Editor do Supabase. Depois é só recarregar.')+'</div>';
  const P=petGet(),now=Date.now(),coins=balance(UI.me);
  let h='<div class="row sp"><div><strong>Faxinho</strong><div class="sm muted">O bichinho que depende das suas tarefas</div></div><span class="pill coin">'+px('coin.png',14)+' '+coins+' moedas</span></div>';
  if(!P||!P.cur)return h+'<section class="card col tut"><div class="pegg-big">'+fxEgg(7,0,8).replace('class="fx egg','class="fx egg bob')+'</div><h2>Um ovo misterioso</h2><p>Existem 10 animais diferentes escondidos nos ovos. Cuide bem, porque ele vive cerca de '+PET_LIFE_DAYS+' dias.</p><button class="btn green" data-a="pget">Receber meu ovo</button></section>'+petAlbum(P)+petNotifCard();
  const st=petCur(P),mood=petMood(st,now),sp=st.species&&spec(st.species);
  if(st.stage==='egg'){
    h+='<section class="card col pet">'+petSprite(st,P,now)+'<h3>Ovo misterioso</h3><div class="pv"><span class="pl">'+pxi('temp',3)+'<span>Calor</span></span><div class="bar"><i style="width:'+Math.round(st.warm)+'%;background:var(--orange)"></i></div><span class="pn">'+Math.round(st.warm)+'%</span></div><p class="sm muted">'+esc(mood.t)+' Esquente a cada 15 minutos para chocar mais rápido. Sozinho ele também esquenta, devagar.</p><button class="btn yellow" data-a="pwarm">Aquecer o ovo</button></section>';
    return h+petAlbum(P)+petLife(st)+petNotifCard();
  }
  const sg=PET_STAGES.find(x=>x[0]===st.stage),age=st.hatchedAt?Math.min(PET_LIFE_DAYS,Math.floor((st.t-st.hatchedAt)/DAY)+1):0;
  h+='<section class="card col pet">'+petSprite(st,P,now)+
   '<div class="row sp"><div><h3>'+esc(st.name||sp.n)+'</h3><div class="sm muted">'+esc(sp.n)+'</div></div><div class="col" style="align-items:flex-end;gap:4px"><span class="pill">'+(sg?sg[1]:'Despedida')+'</span><span class="pill '+(sp.r==='lendário'?'lv':'')+'">'+sp.r+'</span></div></div>'+
   '<div class="bubble" role="status">'+esc(mood.t)+'</div>'+
   '<div class="hud-row" title="Saúde"><span class="hl">VIDA</span><span class="hb" aria-hidden="true">'+hearts(Math.max(0,Math.round(st.health/20)),5)+'</span></div>'+
   (!st.named&&!st.dead?'<button class="btn sm yellow" data-a="pname">Dar um nome</button>':'')+
   '<div class="sm muted">Dia '+age+' de '+PET_LIFE_DAYS+(st.form?' · forma '+st.form:'')+' · '+st.mistakes+' descuido(s)</div>';
  if(st.dead){
    const left=Math.max(0,PET_REVIVE_H-(now-st.dead)/HR);
    h+=(left>0?'<p>A Poção da Fênix ainda pode trazê-lo de volta (restam '+Math.ceil(left)+'h).</p><button class="btn yellow" data-a="previve">Reviver por 40 moedas</button>':'<p>Já passou do tempo de reviver.</p>')+'<button class="btn" data-a="pegg">Chocar outro ovo (20 moedas)</button></section>';
    return h+petAlbum(P)+petLife(st)+petNotifCard();
  }
  const I=n=>pxi(n,3);
  h+='<div class="pvs">'+petBar(I('racao'),'Fome',st.hunger)+petBar(I('agua'),'Sede',st.thirst)+petBar(I('bola'),'Diversão',st.fun)+petBar(px('ui-bolt-full.png',12),'Energia',st.energy)+petBar(I('banho'),'Higiene',st.hygiene)+petBar(I('carinho'),'Carinho',st.love)+petBar(I('temp'),'Clima',st.temp,true)+'</div></section>';
  const b=k=>'<button class="btn pbtn" data-a="pact" data-k="'+k+'">'+pxi(PET_ACTICON[k],4)+'<span class="pt">'+PET_LABEL[k]+'</span><span class="sm">'+(PET_ACT[k].cost?px('coin.png',9)+' '+PET_ACT[k].cost:'grátis')+'</span></button>';
  h+='<section class="card col"><h3>Cuidar</h3><div class="pact">'+['racao','fruta','banquete','agua','brincar','passear','carinho','banho','limpar','cobertor','gelo','remedio'].map(b).join('')+'</div></section>';
  h+=petShop(P)+petAlbum(P)+petLife(st)+petNotifCard();
  return h;
}
function petShop(P){
  const own=petOwn(P);
  const ico=it=>it.cos?pixSvg(FX_ACC[it.id].r,Object.assign({},FXG,FX_ACC[it.id].pal),it.id==='oculos'?3:4):it.id==='casinha'?pxi('casinha',2):it.id==='cama'?pxi('caminha',3):pxi('bola',4);
  return '<section class="card col"><h3>Loja do Faxinho</h3><div class="col pshop">'+PET_SHOP.map(it=>{const has=own.includes(it.id);
    return '<div class="row sp"><div class="row"><span class="sico">'+ico(it)+'</span><div><strong>'+it.n+'</strong>'+(it.d?'<div class="sm muted">'+it.d+'</div>':'<div class="sm muted">Enfeite</div>')+'</div></div>'+
     (has?(it.cos?'<button class="btn sm '+(P.wear===it.id?'yellow':'')+'" data-a="pwear" data-k="'+it.id+'">'+(P.wear===it.id?'Usando':'Usar')+'</button>':'<span class="pill">Comprado</span>'):'<button class="btn sm green" data-a="pbuy" data-k="'+it.id+'">'+px('coin.png',10)+' '+it.cost+'</button>')+'</div>'}).join('')+'</div></section>';
}
function petAlbum(P){
  const al=(P&&P.album)||{};
  return '<section class="card col"><h3>Álbum de Faxinhos ('+Object.keys(al).length+'/10)</h3><p class="sm muted">Cada ovo esconde um animal. Quem já chocou aparece aqui.</p><div class="album">'+PET_SPECIES.map(s=>{const a=al[s.id];
    return '<div class="slot '+(a?'got':'')+'" title="'+(a?esc(s.n):'???')+'">'+petSpr(s.id,{px:3,mood:a?'happy':'sleep',cls:a?'':'sil'})+'<span class="sm">'+(a?esc(s.n.split(' ')[0]):'???')+'</span></div>'}).join('')+'</div></section>';
}
function petLife(st){
  const age=st&&st.hatchedAt?(st.t-st.hatchedAt)/DAY:0,sid=st&&st.species;
  return '<section class="card col"><h3>Ciclo de vida</h3><p class="sm muted">Cerca de '+PET_LIFE_DAYS+' dias, em 6 fases. Quem cuida bem evolui para a forma radiante.</p><ol class="life">'+PET_STAGES.map((x,i)=>{const nx=PET_STAGES[i+1]?PET_STAGES[i+1][3]:PET_LIFE_DAYS,cur=st&&st.stage===x[0];
    return '<li class="'+(cur?'cur':age>=nx?'done':'')+'"><span class="lsp">'+(sid?petSpr(sid,{px:2,stage:x[0],mood:'happy'}):fxEgg(i+2,0,2))+'</span><div><strong>'+x[1]+'</strong><div class="sm muted">dia '+x[3]+' a '+nx+'</div></div></li>'}).join('')+'</ol></section>';
}
function petNotifCard(){
  const sup='Notification' in window,on=sup&&Notification.permission==='granted'&&LS.get('rdf:pnon')==='1';
  return '<section class="card col"><h3>Avisos</h3><p class="sm muted">'+(sup?'Receba um aviso quando o Faxinho estiver com fome, sede, frio, calor, tédio ou doente. Os avisos chegam enquanto o app estiver aberto, em segundo plano ou instalado e ativo.':'Este navegador não oferece avisos.')+'</p>'+(sup?'<button class="btn '+(on?'':'yellow')+'" data-a="pnotif">'+(on?'Desligar avisos':'Ligar avisos')+'</button>':'')+'</section>';
}
/* ---- avisos ---- */
function petAlerts(st,now){
  if(!st||st.dead||st.retired||st.stage==='egg')return [];
  const sl=inSleep(new Date(now).getHours(),spec(st.species).sleep),a=[];
  if(st.sick)a.push(['sick','Não estou me sentindo bem. Preciso de remédio.']);
  if(sl)return a;
  if(st.hunger<=25)a.push(['hunger','Estou com fome!']);if(st.thirst<=25)a.push(['thirst','Estou com sede!']);
  if(st.temp<=32)a.push(['cold','Estou com frio!']);if(st.temp>=68)a.push(['hot','Estou com calor!']);
  if(st.fun<=20)a.push(['fun','Estou entediado...']);if(st.pf>=2||st.hygiene<=20)a.push(['hyg','Aqui está sujo!']);
  if(st.love<=20)a.push(['love','Quero carinho.']);return a;
}
function petNotify(title,body,tag){
  try{
    const o={body,icon:'icons/icon-192.png',badge:'icons/icon-192.png',tag:'faxinho-'+tag,data:{url:'./'}};
    if(navigator.serviceWorker&&navigator.serviceWorker.ready)navigator.serviceWorker.ready.then(r=>r.showNotification(title,o)).catch(()=>{try{new Notification(title,o)}catch(e){}});
    else new Notification(title,o);
  }catch(e){}
}
function petWatch(){
  try{
    if(!UI.me||!S.pets||!('Notification' in window)||Notification.permission!=='granted'||LS.get('rdf:pnon')!=='1')return;
    const P=petGet();if(!P||!P.cur)return;const now=Date.now(),st=petCur(P);
    for(const [k,t] of petAlerts(st,now)){const key='rdf:pn:'+UI.me+':'+k,last=+(LS.get(key)||0);if(now-last>3*HR){LS.set(key,String(now));petNotify(st.name||'Faxinho',t,k)}}
  }catch(e){}
}
function petAttention(){const P=UI.me&&S.pets&&petGet();if(!P||!P.cur)return 0;const st=petCur(P);return st.dead?1:petAlerts(st,Date.now()).length}
setInterval(()=>{petWatch();if(typeof render==='function'&&UI.view==='pet'&&!UI.modal&&!UI.act&&!document.hidden&&!(document.activeElement&&/INPUT|TEXTAREA|SELECT/.test(document.activeElement.tagName)))render()},60000);
document.addEventListener('visibilitychange',()=>{if(!document.hidden){petWatch();petCheck()}});

function petHome(){
  const me=user(UI.me);if(!plays(me))return '';
  const P=petGet();if(REMOTE&&Remote.petsOk===false)return '';
  if(!P||!P.cur)return '<section class="card row sp pmini"><div class="row"><span class="pm-s">'+fxEgg(7,0,3)+'</span><div><strong>Faxinho</strong><div class="sm muted">Um ovo misterioso espera por você.</div></div></div><button class="btn sm green" data-a="go" data-v="pet">Pegar ovo</button></section>';
  const st=petCur(P),now=Date.now(),m=petMood(st,now),sp=st.species&&spec(st.species);
  const spr=st.stage==='egg'?fxEgg(st.seed,st.warm,3):petSpr(st.species,{px:3,mood:petFace(st,now).mood,stage:st.stage,wear:P.wear,form:st.form});
  return '<section class="card row sp pmini"><div class="row"><span class="pm-s">'+spr+'</span><div><strong>'+esc(st.name||(sp?sp.n:'Ovo misterioso'))+'</strong><div class="sm muted">'+esc(m.t)+'</div></div></div><button class="btn sm '+(m.sev?'yellow':'')+'" data-a="go" data-v="pet">'+(m.sev?'Cuidar':'Ver')+'</button></section>';
}
