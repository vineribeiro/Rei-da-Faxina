/* ===== Faxinhos: sprites 8 bits gerados por código (24x24) =====
   Corpo redondo "chibi", olhos grandes com brilho, bochechas, contorno automático.
   Cada animal tem peças próprias (orelhas, chifres, asas, bico...). Humores trocam o rosto. */
const FXW=24;
const FXG={o:'#2a1740',w:'#FFFFFF',e:'#2d1b45',c:'#FF9FBF',m:'#7a2f55',p:'#FF7FA0',g:'#1d1b30',r:'#E0323B',R:'#A8222B',y:'#FFC21A',Y:'#C78A00',q:'#8FD8FF',Q:'#4FA8E8',z:'#9BE564',Z:'#4FA83A',n:'#8A5A32',N:'#5E3A1E',t:'#EBCB8B',T:'#C9A25E'};
const fxSet=(g,x,y,k)=>{if(x>=0&&x<FXW&&y>=0&&y<FXW)g[y][x]=k};
const fxGrid=()=>Array.from({length:FXW},()=>Array(FXW).fill(null));
function fxStamp(g,rows,ox,oy,mir){rows.forEach((r,j)=>{for(let i=0;i<r.length;i++){const k=r[i];if(k==='.'||k===' ')continue;fxSet(g,ox+i,oy+j,k);if(mir)fxSet(g,FXW-1-(ox+i),oy+j,k)}})}
/* peças: l = camada (back atrás do corpo, front à frente), m = espelhar */
const FX_SP={
 dragao:{n:'Dragãozinho Brasa',pal:{b:'#EE5A3E',l:'#FF8D6B',d:'#B93B2E',k:'#FFD98A',a:'#FFB02E',A:'#C9452F',h:'#FFF1C9'},
  parts:[{l:'back',m:1,x:0,y:7,r:['.....A','....AA','...AAd','..AAAd','.AAAdd','AAAAd.','.AAd..']},
         {l:'back',m:0,x:19,y:17,r:['.bb.','bbbb','.bba','..aa']},
         {l:'front',m:1,x:6,y:2,r:['h.','hh','hh','hh','.h','.h']},
         {l:'front',m:0,x:11,y:4,r:['AA','AA','AA']},
         {l:'front',m:0,x:11,y:14,r:['dd']}]},
 unicornio:{n:'Unicórnio Aurora',pal:{b:'#F6F1FF',l:'#FFFFFF',d:'#CFC4EE',k:'#FFE6F3',a:'#FF8FC8',A:'#8FD3FF',h:'#FFD84A',H:'#E8A800',p:'#FFB0D6'},
  parts:[{l:'back',m:1,x:5,y:2,r:['.b','bb','bp','bd']},
         {l:'back',m:0,x:19,y:16,r:['.aA','aAa','.Aa','.aA','..a']},
         {l:'front',m:0,x:11,y:0,r:['hh','hH','hh','hH','hh']},
         {l:'front',m:0,x:8,y:6,r:['aAaAaAaA','.aAaAaA.','..a..A..']}]},
 coruja:{n:'Coruja Lunar',pal:{b:'#8B5E3C',l:'#B27F55',d:'#5E3D26',k:'#F3DDB0',a:'#FFD34E',A:'#3F2817',h:'#FF9A3C'},feet:'h',
  parts:[{l:'back',m:1,x:4,y:1,r:['.A','AA','AAA','AAAA','.AAA']},
         {l:'front',m:1,x:1,y:13,r:['dd','dd','dd','dd','.d']},
         {l:'front',m:1,x:5,y:10,r:['.aaa.','aaaaa','aaaaa','aaaaa','aaaaa','.aaa.']},
         {l:'front',m:0,x:11,y:15,r:['hh','.h']},
         {l:'front',m:0,x:10,y:18,r:['d..d','.dd.']}],noMouth:true},
 raposa:{n:'Raposa Ruiva',pal:{b:'#F28A2E',l:'#FFB35C',d:'#C45F17',k:'#FFF1DA',a:'#3A2A24',A:'#E06A12'},
  parts:[{l:'back',m:1,x:4,y:0,r:['...a','..aa','.aka','.akb','akkb','abbb','bbbb']},
         {l:'back',m:0,x:19,y:13,r:['...bb','..bbb','.bbbb','bbbbk','.bbkk','..kk.']},
         {l:'front',m:1,x:2,y:15,r:['kk','kkk','.kk']},
         {l:'front',m:0,x:9,y:15,r:['kkkkkk','kkkkkk','.kkkk.']},
         {l:'front',m:0,x:11,y:14,r:['aa']}],noMouth:true,mouthY:17},
 polvo:{n:'Polvo Marujo',pal:{b:'#B96CEB',l:'#D9A0FF',d:'#8C45C4',k:'#EBC8FF',a:'#FF7AB6',A:'#FFD34E',Q:'#3D6FD0',W:'#FFFFFF'},feet:false,
  parts:[{l:'front',m:1,x:3,y:19,r:['dd','dd','dd','.d']},
         {l:'front',m:1,x:7,y:20,r:['dd','dd','.d']},
         {l:'front',m:1,x:4,y:21,r:['k']},
         {l:'front',m:0,x:7,y:3,r:['..QQQQQQ..','.QQQQQQQQ.','.QQQQQQQQ.','WWWWWWWWWW']},
         {l:'front',m:0,x:9,y:9,r:['aa','aa']},
         {l:'front',m:0,x:15,y:8,r:['a','a']},
         {l:'front',m:0,x:17,y:10,r:['aa']}]},
 morcego:{n:'Morcego Noturno',pal:{b:'#6F52A8',l:'#9A82D0',d:'#46306F',k:'#CDBDF2',a:'#FF9EC4',A:'#8A6FD4'},
  parts:[{l:'back',m:1,x:0,y:8,r:['.....A','....AA','...AdA','..AddA','.AdAAd','AdAAd.','AAd...','Ad....']},
         {l:'back',m:1,x:4,y:0,r:['.A','AA','AaA','AaAA','AaAA','bbbb','bbbb']},
         {l:'front',m:1,x:10,y:17,r:['w']}]},
 pinguim:{n:'Pinguim Gelado',pal:{b:'#2F4B8C',l:'#4F73C0',d:'#1E2F5E',k:'#FFFFFF',a:'#FF9F2E',A:'#E07A10'},belly:[11.5,17,6.5,4.6],face:[11.5,13,7,4],feet:'a',
  parts:[{l:'front',m:1,x:1,y:13,r:['dd','dd','dd','dd','.d']},
         {l:'front',m:0,x:11,y:15,r:['aa','AA']}],noMouth:true,cheek:'#BFE6FF'},
 lagarto:{n:'Lagartixa Solar',pal:{b:'#5CC15A',l:'#8EE07A',d:'#3A8F3E',k:'#EAF6B2',a:'#FFD34E',A:'#2F6B35'},
  parts:[{l:'back',m:0,x:19,y:15,r:['.bb.','bbbb','.bbb','..bb','.bbA','..AA']},
         {l:'front',m:0,x:7,y:3,r:['..a.a.a..','.aaaaaaa.']},
         {l:'front',m:0,x:5,y:9,r:['a']},{l:'front',m:0,x:17,y:10,r:['aa']},{l:'front',m:0,x:14,y:19,r:['a']}]},
 panda:{n:'Panda Soneca',pal:{b:'#F6F6FA',l:'#FFFFFF',d:'#D2D2E0',k:'#FFFFFF',a:'#2B2B3A',A:'#454557'},eyePatch:true,feet:'a',
  parts:[{l:'back',m:1,x:3,y:4,r:['.aaa','aaaa','aaaa','.aa.']},
         {l:'front',m:1,x:1,y:14,r:['aa','aa','aa','aa']},
         {l:'front',m:0,x:11,y:14,r:['aa']}]},
 coelho:{n:'Coelho Pulinho',pal:{b:'#FFE4EF',l:'#FFFFFF',d:'#F2B8D0',k:'#FFFFFF',a:'#FF8FB8',A:'#FFC4DA'},
  parts:[{l:'back',m:1,x:5,y:0,r:['.bbbb','.baab','.baab','.baab','.baab','.baab','.bbbb']},
         {l:'back',m:0,x:20,y:18,r:['.ll','lll','.ll']},
         {l:'front',m:0,x:11,y:14,r:['aa']},
         {l:'front',m:0,x:11,y:17,r:['ww']}]}
};
const FX_IDS=Object.keys(FX_SP);
/* ícones pequenos (sobrepostos ao bichinho) */
const FX_ICON={
 zz:['qqqq','..q.','.q..','qqqq'],
 snow:['.q.q.','..q..','qqqqq','..q..','.q.q.'],
 drop:['.q.','.q.','qqq','qqq','.q.'],
 plus:['.z.','zzz','.z.'],
 stink:['z..z.','.z..z','z..z.','.z..z'],
 spark:['.y.','yyy','.y.'],
 heart:['.r.r.','rrrrr','rrrrr','.rrr.','..r..'],
 zap:['..y','.yy','yyy','.yy','y..'],
 halo:['.yyyyyy.','y......y','.YYYYYY.']
};
function fxMix(hex,to,t){const f=h=>[1,3,5].map(i=>parseInt(h.slice(i,i+2),16)),a=f(hex),b=f(to);return '#'+a.map((v,i)=>Math.round(v+(b[i]-v)*t).toString(16).padStart(2,'0')).join('')}
function fxFace(g,mood,sp){
  const L=6,Rr=15,Y=11;                                   // olhos 3x4
  const eye=(x,half)=>{for(let j=half?2:0;j<4;j++)for(let i=0;i<3;i++)fxSet(g,x+i,Y+j,'e');if(!half){fxSet(g,x,Y,'w');fxSet(g,x+2,Y+3,'w')}else fxSet(g,x,Y+2,'w')};
  const cross=x=>{[[0,1],[2,1],[1,2],[0,3],[2,3]].forEach(([i,j])=>fxSet(g,x+i,Y+j,'e'))};
  const arc=x=>{fxSet(g,x,Y+2,'e');fxSet(g,x+1,Y+3,'e');fxSet(g,x+2,Y+2,'e')};
  const patch=x=>{for(let j=-1;j<=4;j++)for(let i=-1;i<=3;i++)if(!((i===-1||i===3)&&(j===-1||j===4)))fxSet(g,x+i,Y+j,'a')};
  if(sp.eyePatch){patch(L);patch(Rr)}
  const E=fn=>{fn(L);fn(Rr)};
  if(mood==='sleep')E(arc);
  else if(mood==='sick'||mood==='dead')E(cross);
  else if(mood==='bored')E(x=>eye(x,true));
  else{E(x=>eye(x,false));if(mood==='sad'){fxSet(g,L,Y+4,'q');fxSet(g,Rr+2,Y+4,'q');fxSet(g,L+1,Y,'w');fxSet(g,Rr+1,Y,'w')}}
  if(sp.eyePatch&&mood!=='sleep'&&mood!=='sick'&&mood!=='dead'){[L,Rr].forEach(x=>{fxSet(g,x,Y+1,'w');fxSet(g,x,Y+2,'w');fxSet(g,x+1,Y+1,'w');fxSet(g,x+1,Y+2,'w');fxSet(g,x+1,Y+2,'e')})}
  if(mood!=='sick'&&mood!=='dead'){const c=sp.cheek?'C':'c';[[4,15],[5,15],[18,15],[19,15]].forEach(([x,y])=>fxSet(g,x,y,c))}
  if(!sp.noMouth){
    const my=sp.mouthY||16;
    if(mood==='hungry'){[10,11,12,13].forEach(x=>fxSet(g,x,my,'m'));fxSet(g,11,my+1,'p');fxSet(g,12,my+1,'p')}
    else if(mood==='sad'){fxSet(g,10,my+1,'m');fxSet(g,13,my+1,'m');fxSet(g,11,my,'m');fxSet(g,12,my,'m')}
    else if(mood==='sick'){fxSet(g,10,my,'m');fxSet(g,11,my+1,'m');fxSet(g,12,my,'m');fxSet(g,13,my+1,'m')}
    else if(mood==='bored'||mood==='dead'){[10,11,12,13].forEach(x=>fxSet(g,x,my,'m'))}
    else if(mood==='sleep'){fxSet(g,11,my,'m');fxSet(g,12,my,'m')}
    else{fxSet(g,10,my-1,'m');fxSet(g,13,my-1,'m');fxSet(g,11,my,'m');fxSet(g,12,my,'m')}
  }
}
/* acessórios (compra na loja) */
const FX_ACC={
 laco:{r:['aa.aa','aaAaa','aa.aa'],x:14,y:5,pal:{a:'#FF5FA2',A:'#C93C7E'}},
 oculos:{r:['ggggg.ggggg','gwggg.gggwg','ggggg.ggggg','.ggg...ggg.'],x:5,y:11,pal:{}},
 cartola:{r:['..gggggggg..','..gggggggg..','..rrrrrrrr..','gggggggggggg'],x:6,y:2,pal:{}},
 cachecol:{r:['rrrrrrrrrrrr','RRRRRRRRRRRR','.........rr.','.........RR.'],x:6,y:19,pal:{}},
 coroa:{r:['y.y.y.y','yyyyyyy','yyryyry','YYYYYYY'],x:8,y:3,pal:{}}
};
/* gera a grade de pixels de um bichinho */
function fxBuild(id,o){
  o=o||{};const sp=FX_SP[id],g=fxGrid(),mood=o.mood||'happy';
  let pal=Object.assign({},FXG,sp.pal);
  if(sp.cheek)pal.C=sp.cheek;
  // tons por estado
  const tint=(to,t)=>['b','l','d','k','a','A'].forEach(k=>{if(pal[k]&&!(id==='panda'&&(k==='a'||k==='A'))&&!(id==='pinguim'&&k==='k'))pal[k]=fxMix(pal[k],to,t)});
  if(mood==='sick')tint('#8FD35A',.4);else if(o.cold)tint('#7FB6FF',.28);else if(o.hot)tint('#FF7A5A',.18);
  if(mood==='dead')['b','l','d','k','a','A','h'].forEach(k=>{if(pal[k])pal[k]=fxMix(pal[k],'#8a8a96',.75)});
  if(o.form==='rebelde')tint('#7a7a88',.32);
  // camada atrás
  sp.parts.filter(p=>p.l==='back').forEach(p=>fxStamp(g,p.r,p.x,p.y,p.m));
  // corpo
  const cx=11.5,cy=13.5,rx=8.6,ry=8;
  for(let y=0;y<FXW;y++)for(let x=0;x<FXW;x++){
    const dx=(x-cx)/rx,dy=(y-cy)/ry,d=dx*dx+dy*dy;
    if(d<=1){let k='b';if(d>.62&&(dx>.15||dy>.35))k='d';else if(d>.3&&dx<-.25&&dy<-.15&&d<.78)k='l';fxSet(g,x,y,k)}
  }
  // barriga e rosto claro
  const bl=sp.belly||[11.5,17.2,5,3.4];
  for(let y=0;y<FXW;y++)for(let x=0;x<FXW;x++){const dx=(x-bl[0])/bl[2],dy=(y-bl[1])/bl[3];if(dx*dx+dy*dy<=1&&g[y][x])g[y][x]='k'}
  if(sp.face){const f=sp.face;for(let y=0;y<FXW;y++)for(let x=0;x<FXW;x++){const dx=(x-f[0])/f[2],dy=(y-f[1])/f[3];if(dx*dx+dy*dy<=1&&g[y][x])g[y][x]='k'}}
  if(sp.feet!==false){const fk=sp.feet||'d';fxStamp(g,['kkk','kkk'].map(r=>r.replace(/k/g,fk)),6,21,0);fxStamp(g,['kkk','kkk'].map(r=>r.replace(/k/g,fk)),15,21,0)}
  sp.parts.filter(p=>p.l==='front').forEach(p=>fxStamp(g,p.r,p.x,p.y,p.m));
  // enfeites por fase
  const st=o.stage;
  if(st==='baby')fxStamp(g,['w.w.w.w.w','wwwwwwwww'],7,4,0);          // casquinha de ovo
  if(st==='teen'){fxStamp(g,['.z.','zzz','.Z.'],11,2,0)}               // broto
  if(st==='senior')fxStamp(g,['rrrrrrrrrrrr'],6,19,0);// lenço
  if(st==='elder'){fxStamp(g,['www.....www'],6,9,0)}                  // sobrancelhas brancas
  // acessório
  const face=fxGrid();fxFace(face,mood,sp);
  for(let y=0;y<FXW;y++)for(let x=0;x<FXW;x++)if(face[y][x])g[y][x]=face[y][x];
  if(o.wear&&FX_ACC[o.wear]){const a=FX_ACC[o.wear];Object.assign(pal,a.pal);fxStamp(g,a.r,a.x,a.y,0)}
  if(mood==='dead')fxStamp(g,FX_ICON.halo,8,0,0);
  // contorno automático
  const out=g.map(r=>r.slice());
  for(let y=0;y<FXW;y++)for(let x=0;x<FXW;x++)if(!g[y][x]){
    if([[1,0],[-1,0],[0,1],[0,-1]].some(([a,b])=>g[y+b]&&g[y+b][x+a]&&g[y+b][x+a]!=='_'))out[y][x]='o';
  }
  return {g:out,pal,eyes:!(mood==='sleep'||mood==='dead')};
}
/* ícones sobrepostos: devolve grade adicional */
function fxOverlayIcons(list){const g=fxGrid();list.forEach(([n,x,y])=>fxStamp(g,FX_ICON[n],x,y,0));return g}
/* SVG com retângulos agrupados por linha */
function fxSvg(grid,pal,px,cls,blink){
  let rects='',eyeRects='';
  for(let y=0;y<FXW;y++){
    let x=0;
    while(x<FXW){
      const k=grid[y][x];if(!k){x++;continue}
      let x2=x;while(x2+1<FXW&&grid[y][x2+1]===k)x2++;
      const col=pal[k]||FXG[k]||'#f0f';const r='<rect x="'+x+'" y="'+y+'" width="'+(x2-x+1)+'" height="1" fill="'+col+'"/>';
      if(blink&&(k==='e'||k==='w')&&y>=11&&y<=15&&((x>=6&&x<=9)||(x>=15&&x<=18)))eyeRects+=r;else rects+=r;
      x=x2+1;
    }
  }
  return '<svg class="fx '+(cls||'')+'" viewBox="0 0 '+FXW+' '+FXW+'" width="'+FXW*px+'" height="'+FXW*px+'" shape-rendering="crispEdges" aria-hidden="true">'+rects+(eyeRects?'<g class="blink">'+eyeRects+'</g>':'')+'</svg>';
}
const fxCache={};
function fxSprite(id,o){
  o=o||{};const key=[id,o.mood,o.stage,o.wear,o.form,o.cold?1:0,o.hot?1:0,o.px,o.cls,o.icons?o.icons.join('|'):''].join(',');
  if(fxCache[key])return fxCache[key];
  const b=fxBuild(id,o);
  if(o.icons)o.icons.forEach(([n,x,y])=>fxStamp(b.g,FX_ICON[n],x,y,0));
  return fxCache[key]=fxSvg(b.g,b.pal,o.px||5,o.cls,b.eyes);
}
/* ovo misterioso: manchas vêm da semente, sem entregar o bicho */
function fxEgg(seed,warm,px){
  const g=fxGrid(),cols=['#FF8FB8','#8FD8FF','#FFD34E','#A58BFF','#7FE3A0'],ac=cols[seed%5],ac2=cols[(seed*7+2)%5];
  const pal=Object.assign({},FXG,{b:'#FFF4D6',l:'#FFFFFF',d:'#E5CF9E',a:ac,A:ac2});
  const cx=11.5,cy=13.5,rx=7,ry=9;
  for(let y=0;y<FXW;y++)for(let x=0;x<FXW;x++){const dx=(x-cx)/(rx*(y<cy?1:1)),dy=(y-cy)/(y<cy?ry*1.05:ry*.95),d=dx*dx+dy*dy;
    if(d<=1){let k='b';if(d>.62&&(dx>.1||dy>.3))k='d';else if(d>.3&&dx<-.2&&dy<-.1&&d<.8)k='l';g[y][x]=k}}
  const sp=[[8,9,3,2],[14,12,3,2],[8,15,2,2],[13,17,3,2],[11,7,2,1]];
  sp.forEach(([x,y,w,h],i)=>{for(let j=0;j<h;j++)for(let k=0;k<w;k++)if(g[y+j]&&g[y+j][x+k])g[y+j][x+k]=i%2?'A':'a'});
  if(warm>=40&&warm<70){fxSet(g,9,13,'e');fxSet(g,10,14,'e');fxSet(g,11,13,'e');fxSet(g,14,13,'e');fxSet(g,15,14,'e');fxSet(g,16,13,'e');fxSet(g,8,15,'c');fxSet(g,17,15,'c');fxSet(g,12,16,'m');fxSet(g,13,16,'m')}
  if(warm>=70){[[11,6],[12,7],[11,8],[12,9],[13,10],[12,11],[13,12],[14,12]].forEach(([x,y])=>fxSet(g,x,y,'e'));fxSet(g,9,14,'e');fxSet(g,10,14,'e');fxSet(g,15,14,'e');fxSet(g,16,14,'e');fxSet(g,8,16,'c');fxSet(g,17,16,'c')}
  const out=g.map(r=>r.slice());
  for(let y=0;y<FXW;y++)for(let x=0;x<FXW;x++)if(!g[y][x]&&[[1,0],[-1,0],[0,1],[0,-1]].some(([a,b])=>g[y+b]&&g[y+b][x+a]))out[y][x]='o';
  return fxSvg(out,pal,px||6,'egg'+(warm>=70?' crack':''),false);
}
/* pequenos desenhos soltos (qualquer tamanho): cocô, itens, ícones de ação */
function pixSvg(rows,pal,px,cls){
  const w=Math.max(...rows.map(r=>r.length)),h=rows.length;let s='';
  rows.forEach((r,y)=>{let x=0;while(x<r.length){const k=r[x];if(k==='.'||k===' '){x++;continue}let x2=x;while(x2+1<r.length&&r[x2+1]===k)x2++;s+='<rect x="'+x+'" y="'+y+'" width="'+(x2-x+1)+'" height="1" fill="'+(pal[k]||FXG[k]||'#f0f')+'"/>';x=x2+1}});
  return '<svg class="pxs '+(cls||'')+'" viewBox="0 0 '+w+' '+h+'" width="'+w*px+'" height="'+h*px+'" shape-rendering="crispEdges" aria-hidden="true">'+s+'</svg>';
}
const PXI={
 poop:{r:['...nn...','..nnnn..','.nnnnnn.','nnenneNn','NNNNNNNN'],p:{n:'#9A6234',N:'#6A3F1C',e:'#fff'}},
 racao:{r:['.oo..oo.','oyyooyyo','.oyyyyo.','..oyyo..','.oyyyyo.','oyyooyyo','.oo..oo.'],p:{o:'#5E3D26',y:'#F2C77A'}},
 fruta:{r:['....z...','...zz...','.rrrrrr.','rRrrrrrr','rrrrrrrr','rrrrrrrr','.rrrrrr.','..rr.rr.'],p:{}},
 banquete:{r:['..r..r..','..y..y..','.wwwwww.','wppwwppw','.wwwwww.','nnnnnnnn','NnnnnnnN','.NNNNNN.'],p:{p:'#FF7FA0',n:'#B97A3A',N:'#7A4A1E'}},
 agua:{r:['...q....','..qq....','..qqq...','.qqqqq..','qqwqqqq.','qqwqqqq.','qqqqqQq.','.qqqQq..'],p:{}},
 bola:{r:['..rrrr..','.rrwwrr.','rrwwrrrr','rwwrrrrr','rrrrrrrr','rrrrrrRR','.rrrRRR.','..RRRR..'],p:{}},
 arvore:{r:['..zzzz..','.zzzzzz.','zzzzzzzz','zzzzzzzz','.zzzzzz.','...nn...','...nn...','..nnnn..'],p:{n:'#8A5A32'}},
 carinho:{r:['.rr.rr.','rrrrrrr','rrrrrrr','.rrrrr.','..rrr..','...r...'],p:{}},
 banho:{r:['.q...q.','qwq.qwq','.q.q.q.','..qwq..','wwwwwww','wqqqqqw','.wwwww.'],p:{}},
 vassoura:{r:['.....nn.','....nn..','...nn...','..nn....','.tttt...','tttttt..','TTTTTT..'],p:{}},
 cobertor:{r:['rrrrrrrr','rwrwrwrw','RrRrRrRr','rrrrrrrr','rwrwrwrw','RrRrRrRr','.R.R.R.R'],p:{}},
 gelo:{r:['.qqqqqq.','qwwqqqQq','qwqqqqQq','qqqqqqQq','qqqqqQQq','.qQQQQq.'],p:{}},
 remedio:{r:['..wwww..','.wwwwww.','wwrrrrww','wwrrrrww','wrrwwrrw','.rrrrrr.','..rrrr..'],p:{}},
 casinha:{r:['.........rr.........','.......rrrrrr.......','.....rrrrrrrrrr.....','...rrrrrRRRRrrrrr...','.rrrrrrRRRRRRrrrrrr.','rrrrrrRRRRRRRRrrrrrr','..tttttttttttttttt..','..ttTttttttttTttttt.','..ttttttnnnnttttttt.','..ttttttnNNnttttttt.','..ttttttnNNnttttttt.','..ttttttnNNnttttttt.'],p:{R:'#A8222B',r:'#E0323B',t:'#EBCB8B',T:'#C9A25E',n:'#8A5A32',N:'#2a1740'}},
 caminha:{r:['..pppppppppppppp..','.pPpPpPpPpPpPpPp.','pppppppppppppppppp','nnnnnnnnnnnnnnnnnn','N................N'],p:{p:'#FF9FBF',P:'#FF7FA0',n:'#8A5A32',N:'#5E3A1E'}},
 sol:{r:['y..y..y','.yyyyy.','yyyyyyy','yyyyyyy','.yyyyy.','y..y..y'],p:{}},
 lua:{r:['.wwww.','ww....','ww....','ww....','.wwww.'],p:{w:'#FFF3B8'}},
 nuvem:{r:['..www...','.wwwww.w','wwwwwwww','.wwwwww.'],p:{}},
 temp:{r:['.ooo.','.owo.','.owo.','.orr.','.orr.','orrro','orrro','.ooo.'],p:{w:'#fff',r:'#E0323B',o:'#cfd8ff'}}
};
const pxi=(n,px,cls)=>{const d=PXI[n];return pixSvg(d.r,d.p||{},px,cls)};
