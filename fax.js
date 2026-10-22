/* ===== Faxinhos: arte 8 bits desenhada em código =====
   Cada criatura é montada a partir de formas (elipses, triângulos, retângulos) numa grade de 32x36 células,
   com contorno, sombreamento em 3 tons, olhos brilhantes, bochechas e expressões para cada humor. */
const FXW=32,FXH=36,FX_OL='#2b1c3f',FX_DK='#241a3d';
const fxHex=h=>[1,3,5].map(i=>parseInt(h.slice(i,i+2),16));
const fxRgb=a=>'#'+a.map(v=>Math.max(0,Math.min(255,Math.round(v))).toString(16).padStart(2,'0')).join('');
const fxMix=(a,b,t)=>{const x=fxHex(a),y=fxHex(b);return fxRgb(x.map((v,i)=>v+(y[i]-v)*t))};
const sh=b=>[fxMix(b,'#ffffff',.34),b,fxMix(b,'#3b2457',.34)];
function fxPainter(W,H){
  W=W||FXW;H=H||FXH;const g=Array.from({length:H},()=>Array(W).fill(null));
  const put=(x,y,c)=>{x=Math.floor(x);y=Math.floor(y);if(x>=0&&x<W&&y>=0&&y<H)g[y][x]=c};
  const get=(x,y)=>(x>=0&&x<W&&y>=0&&y<H)?g[y][x]:null;
  const shape=(box,inside,colorAt,stroke)=>{
    for(let y=Math.max(0,Math.floor(box[1]));y<=Math.min(H-1,Math.ceil(box[3]));y++)for(let x=Math.max(0,Math.floor(box[0]));x<=Math.min(W-1,Math.ceil(box[2]));x++){
      const cx=x+.5,cy=y+.5;if(!inside(cx,cy))continue;let c=colorAt(cx,cy);
      if(stroke&&(!inside(cx+1,cy)||!inside(cx-1,cy)||!inside(cx,cy+1)||!inside(cx,cy-1)))c=stroke;g[y][x]=c}
  };
  const P={g,W,H,put,get,
    ell(cx,cy,rx,ry,cols,stroke){
      if(typeof cols==='string')cols=[cols,cols,cols];if(stroke===undefined)stroke=FX_OL;if(stroke===true)stroke=FX_OL;
      shape([cx-rx,cy-ry,cx+rx,cy+ry],(x,y)=>((x-cx)/rx)**2+((y-cy)/ry)**2<=1,(x,y)=>{const nx=(x-cx)/rx,ny=(y-cy)/ry,d=nx*.55+ny*.62;return d>.5?cols[2]:d<-.62?cols[0]:cols[1]},stroke)},
    tri(a,b,c,col,stroke){
      if(typeof col==='string')col=[col,col,col];if(stroke===undefined)stroke=FX_OL;
      const sg=(p,q,r)=>(p[0]-r[0])*(q[1]-r[1])-(q[0]-r[0])*(p[1]-r[1]);
      const inside=(x,y)=>{const p=[x,y],d1=sg(p,a,b),d2=sg(p,b,c),d3=sg(p,c,a),neg=d1<0||d2<0||d3<0,pos=d1>0||d2>0||d3>0;return!(neg&&pos)};
      const xs=[a[0],b[0],c[0]],ys=[a[1],b[1],c[1]];
      shape([Math.min(...xs),Math.min(...ys),Math.max(...xs),Math.max(...ys)],inside,(x,y)=>col[1],stroke)},
    rect(x,y,w,h,col,stroke){
      if(stroke===true)stroke=FX_OL;
      shape([x,y,x+w,y+h],(px,py)=>px>=x&&px<=x+w&&py>=y&&py<=y+h,()=>col,stroke)},
    feet(cx,y,dx,rx,ry,col){P.ell(cx-dx,y,rx,ry,col);P.ell(cx+dx,y,rx,ry,col)},
    pat(x,y,rows,map,flip){rows.forEach((r,j)=>[...r].forEach((ch,i)=>{if(ch==='.'||ch===' ')return;const c=map[ch];if(c)put(x+(flip?r.length-1-i:i),y+j,c)}))}
  };
  return P;
}
/* ---- geometria por fase ---- */
const FX_G={
 baby:{hy:26,hrx:8.8,hry:7.6,fy:33.2,frx:2.5,fry:1.3,fdx:3.8,ey:26.2,bodyless:true},
 child:{hy:22.4,hrx:9.8,hry:8.5,by:30.2,brx:5.4,bry:4.2,fy:33.3,frx:2.8,fry:1.5,fdx:4.5,ey:23},
 teen:{hy:19.8,hrx:10.5,hry:9,by:29.2,brx:6.6,bry:5,fy:33.4,frx:3,fry:1.6,fdx:5,ey:20.4},
 adult:{hy:17.2,hrx:11,hry:9.5,by:27.2,brx:7.5,bry:5.6,fy:33.4,frx:3.2,fry:1.7,fdx:5.4,ey:18.2}};
const fxGeo=stage=>Object.assign({hx:16},FX_G[{baby:'baby',child:'child',teen:'teen',adult:'adult',senior:'adult',elder:'adult'}[stage]||'adult']);
/* ---- corpo comum: cauda/asas atrás -> corpo -> pés -> cabeça ---- */
function fxBase(p,g,col,o){
  o=o||{};const hx=g.hx;
  if(!g.bodyless){p.ell(hx,g.by,g.brx,g.bry,col);if(o.belly)p.ell(hx,g.by+.8,g.brx*.58,g.bry*.72,o.belly,false)}
  p.feet(hx,g.fy,g.fdx,g.frx,g.fry,o.feet||sh(fxMix(col[1],'#3b2457',.18)));
  p.ell(hx,g.hy,g.hrx,g.hry,col);
}
/* ---- espécies ---- */
const FX_SP={
 dragao(p,g,s){const hx=g.hx,top=g.hy-g.hry,B=sh('#f0613f'),belly='#ffe3ae',horn='#fff3cf';
  if(!s.baby){p.tri([hx-g.hrx*.55,g.hy-2],[hx-g.hrx-5,g.hy-g.hry*.55-3],[hx-g.hrx*.9,g.hy+4],sh('#ff9a63'));p.tri([hx+g.hrx*.55,g.hy-2],[hx+g.hrx+5,g.hy-g.hry*.55-3],[hx+g.hrx*.9,g.hy+4],sh('#ff9a63'));
    p.ell(hx+g.brx+1.8,g.by+1.4,3.4,2.3,B);p.tri([hx+g.brx+4,g.by-.5],[hx+g.brx+9,g.by-3.4],[hx+g.brx+5.4,g.by+2.6],'#ffb02e');p.tri([hx+g.brx+5.2,g.by],[hx+g.brx+7.4,g.by-1.8],[hx+g.brx+5.8,g.by+1.6],'#fff2a8',false)}
  fxBase(p,g,B,{belly:belly});
  [-1,1].forEach(d=>p.tri([hx+d*5.8,top+2],[hx+d*4.2,top-3.6],[hx+d*2.2,top+.6],horn));
  p.ell(hx,g.hy+g.hry*.4,g.hrx*.5,g.hry*.36,belly,false);p.put(hx-2,g.hy+g.hry*.3,FX_DK);p.put(hx+1,g.hy+g.hry*.3,FX_DK);
  p.pat(hx-1,top+1,['.','X'],{X:'#ffb02e'}); },
 unicornio(p,g,s){const hx=g.hx,top=g.hy-g.hry,B=sh('#f7f1ff'),M=['#ff8fcf','#8fd3ff','#c3a2ff'];
  if(!s.baby)M.forEach((c,i)=>p.ell(hx+g.brx+1.4+i*.6,g.by+1-i*1.1,2.2,3.6-i*.4,sh(c)));
  fxBase(p,g,B,{feet:sh('#ffb3d9')});
  M.forEach((c,i)=>p.ell(hx-g.hrx*.7+i*.9,g.hy-g.hry*.35+i*1.3,2.6,g.hry*.62,sh(c),i===0?true:false));
  p.ell(hx,g.hy,g.hrx,g.hry,B);
  [-1,1].forEach(d=>p.tri([hx+d*7.4,top+2.4],[hx+d*7,top-2.6],[hx+d*4.2,top+.8],B));
  p.tri([hx-1.9,top+1.2],[hx+.2,top-6.4],[hx+2.2,top+1.2],['#fff2a8','#ffd84a','#e0a526']);p.pat(hx-1,top-3,['X.','.X'],{X:'#ffe98a'});
  p.ell(hx,g.hy,g.hrx,g.hry,B,false);M.forEach((c,i)=>p.ell(hx-g.hrx*.72+i*.9,g.hy-g.hry*.55+i*1.1,2.2,g.hry*.35,sh(c),false)); },
 coruja(p,g,s){const hx=g.hx,top=g.hy-g.hry,B=sh('#b3a6f2');
  if(!s.baby){[-1,1].forEach(d=>p.ell(hx+d*(g.brx+1.4),g.by,2.4,4.4,sh('#8a7ed6')))}
  fxBase(p,g,B,{belly:'#f4edff',feet:sh('#ffb347')});
  if(!s.baby)for(let i=0;i<3;i++)p.put(hx-2+i*2,g.by+1+(i%2),'#cdbfff');
  [-1,1].forEach(d=>p.tri([hx+d*8.6,top+3],[hx+d*7.4,top-3],[hx+d*3.8,top+1.4],sh('#8a7ed6')));
  p.ell(hx,g.hy,g.hrx,g.hry,B);
  [-1,1].forEach(d=>p.ell(hx+d*4.9,g.ey-.2,4.4,4.6,'#fff7ea',false));
  p.tri([hx-1.8,g.hy+g.hry*.3],[hx+1.8,g.hy+g.hry*.3],[hx,g.hy+g.hry*.3+3.2],'#ffb347'); },
 raposa(p,g,s){const hx=g.hx,top=g.hy-g.hry,B=sh('#f58d3a');
  if(!s.baby){p.ell(hx+g.brx+2.4,g.by+.8,4,3.1,B);p.ell(hx+g.brx+5,g.by-.6,2.2,1.9,'#fff6e8')}
  [-1,1].forEach(d=>{p.tri([hx+d*9,top+3.2],[hx+d*7.8,top-5.6],[hx+d*3.2,top+1.4],B);p.tri([hx+d*7.4,top+1.6],[hx+d*7.4,top-3.2],[hx+d*4.6,top+.6],'#ffc2b8',false);p.tri([hx+d*8.1,top-2.2],[hx+d*7.8,top-5.6],[hx+d*6.4,top-3],'#3a2330',false)});
  fxBase(p,g,B,{belly:'#fff4e2',feet:sh('#5a3a3a')});
  [-1,1].forEach(d=>p.ell(hx+d*5.4,g.hy+g.hry*.45,4.3,3.3,'#fff4e2',false));p.rect(hx-1,g.hy+g.hry*.32,2,1,FX_DK,false); },
 polvo(p,g,s){const hx=g.hx,B=sh('#c97df0');
  const rx=g.hrx+.4,ry=g.hry+.2;
  if(!s.baby){const n=4;for(let i=0;i<n;i++){const x=hx-rx*.72+i*(rx*1.44/(n-1));p.ell(x,g.fy-.8+(i%2?.5:0),2.4,g.hry*.55+(i%2?.6:0),B)}
    for(let i=0;i<n;i++)p.put(hx-rx*.72+i*(rx*1.44/(n-1)),g.fy,'#f3c6ff')}
  else{p.feet(hx,g.fy,g.fdx,g.frx+.4,g.fry+.2,B)}
  p.ell(hx,g.hy,rx,ry,B);[[-5,-4],[4,-5],[6,-1]].forEach(a=>p.put(hx+a[0],g.hy+a[1]*.8,'#a557d0'));
  p.ell(hx,g.hy-ry+1.4,rx*.5,1.6,'#ffffff');p.rect(hx-rx*.5,g.hy-ry+2.2,rx,1.4,'#3b64c8',false);p.rect(hx-1,g.hy-ry-.8,2,2,'#3b64c8',false); },
 morcego(p,g,s){const hx=g.hx,top=g.hy-g.hry,B=sh('#8a6bc0'),W=sh('#6a4f9e');
  if(!s.baby)[-1,1].forEach(d=>{p.tri([hx+d*(g.hrx-1),g.hy+1],[hx+d*(g.hrx+9),g.hy-5],[hx+d*(g.hrx+2),g.hy+g.hry*.9],W);p.tri([hx+d*(g.hrx+9),g.hy-5],[hx+d*(g.hrx+7),g.hy+3],[hx+d*(g.hrx+4),g.hy+2],'#ff9ac1',false)});
  [-1,1].forEach(d=>{p.tri([hx+d*9,top+3.4],[hx+d*8.4,top-5],[hx+d*3.6,top+1.2],B);p.tri([hx+d*7.6,top+1.8],[hx+d*7.8,top-2.6],[hx+d*5,top+.6],'#ff9ac1',false)});
  fxBase(p,g,B,{belly:'#d9c6f4',feet:sh('#5a437f')});
  p.pat(hx-2,g.hy+g.hry*.62,['X..X','.XX.'],{X:'#ffffff'}); },
 pinguim(p,g,s){const hx=g.hx,B=sh('#4467b0');
  if(!s.baby)[-1,1].forEach(d=>p.ell(hx+d*(g.brx+1.1),g.by-.4,2,4.2,sh('#35539a')));
  fxBase(p,g,B,{belly:'#ffffff',feet:sh('#ffa826')});
  p.ell(hx,g.hy+g.hry*.14,g.hrx*.84,g.hry*.78,'#ffffff',false);[-1,1].forEach(d=>p.ell(hx+d*4.6,g.hy+g.hry*.12,3.9,3.9,'#ffffff',false));
  p.tri([hx-2,g.hy+g.hry*.34],[hx+2,g.hy+g.hry*.34],[hx,g.hy+g.hry*.34+2.6],['#ffd067','#ffa826','#d97b0b']);
  p.put(hx-1,g.hy-g.hry+.5,'#9fd3ff');p.put(hx,g.hy-g.hry-.5,'#9fd3ff');p.put(hx+1,g.hy-g.hry+.5,'#9fd3ff'); },
 lagarto(p,g,s){const hx=g.hx,top=g.hy-g.hry,B=sh('#86d94a');
  if(!s.baby){p.ell(hx+g.brx+2,g.by+2,4.4,2,B);p.ell(hx+g.brx+6.2,g.by+.2,2.2,1.7,B);p.ell(hx+g.brx+7.6,g.by-1.6,1.4,1.4,B)}
  fxBase(p,g,B,{belly:'#f7ffcf',feet:sh('#5cae2b')});
  [-4,0,4].forEach(x=>p.tri([hx+x-1.6,top+1.2],[hx+x,top-2.8],[hx+x+1.6,top+1.2],sh('#ffd23f')));
  p.ell(hx,g.hy,g.hrx,g.hry,B);[[-6,-2],[6,-3],[7,1],[-7,2]].forEach(a=>p.put(hx+a[0],g.hy+a[1],'#5cae2b'));
  p.pat(hx-1,top+1.4,['.X.','XXX','.X.'],{X:'#ff9d2e'}); },
 panda(p,g,s){const hx=g.hx,top=g.hy-g.hry,B=sh('#f8f6fb'),K=sh('#2f2c3d');
  [-1,1].forEach(d=>p.ell(hx+d*(g.hrx-2.4),top+1.6,3.2,3,K));
  if(!s.baby)[-1,1].forEach(d=>p.ell(hx+d*(g.brx+.8),g.by-.6,2.3,3.8,K));
  fxBase(p,g,B,{belly:'#ffffff',feet:K});
  [-1,1].forEach(d=>p.ell(hx+d*4.9,g.ey+.2,3.6,4.3,K,false));p.rect(hx-1,g.hy+g.hry*.3,2,1.4,FX_DK,false); },
 coelho(p,g,s){const hx=g.hx,top=g.hy-g.hry,B=sh('#ffe0ef'),P=sh('#ff9fc8');
  if(!s.baby)p.ell(hx+g.brx+1.4,g.by+1.6,2.5,2.5,sh('#ffffff'));
  p.ell(hx-5.4,top-1.6,2.6,6.8,B);p.ell(hx-5.4,top-1,1.2,4.8,P,false);
  p.ell(hx+5.4,top-1.4,2.6,6.4,B);p.ell(hx+5.4,top-.8,1.2,4.4,P,false);
  fxBase(p,g,B,{belly:'#ffffff',feet:sh('#ffc2dd')});
  p.rect(hx-1,g.hy+g.hry*.3,2,1,'#e0568f',false);
  p.pat(hx-8,g.hy+g.hry*.45,['X.','.X'],{X:'#cfa0bd'});p.pat(hx+7,g.hy+g.hry*.45,['.X','X.'],{X:'#cfa0bd'}); }
};
/* ---- rosto ---- */
const FX_EYE={open:['.XX.','XXXX','XXXX','XXXX','.XX.'],happy:['.XX.','X..X'],sleep:['XXXX'],half:['XXXX','XXXX','.XX.'],sick:['.XX.','X..X','X.XX','.XX.'],dead:['X..X','.XX.','.XX.','X..X']};
const FX_FACE={
 happy:{e:'open',m:'w',ch:'#ff9fb8'},joy:{e:'happy',m:'open',ch:'#ff7fa3',heart:1},hungry:{e:'open',m:'o',ch:'#ff9fb8',brow:'sad'},thirsty:{e:'open',m:'tongue',ch:'#ff9fb8'},
 cold:{e:'open',m:'chat',ch:'#9fdcff',tint:['#a8d8ff',.2],snow:1},hot:{e:'half',m:'o',ch:'#ff5a5a',tint:['#ff7a5a',.14],sweat:1},dirty:{e:'open',m:'frown',ch:'#ff9fb8',brow:'sad',stink:1},
 bored:{e:'half',m:'flat',ch:'#ff9fb8'},tired:{e:'half',m:'o',ch:'#ff9fb8'},lonely:{e:'open',m:'frown',ch:'#ff9fb8',brow:'sad',tear:1},
 sick:{e:'sick',m:'sick',ch:'#bde87a',tint:['#a7e05a',.3]},sleep:{e:'sleep',m:'o',ch:'#ff9fb8',z:1},dead:{e:'dead',m:'flat',ch:'#c9c3d6',gray:1,halo:1},angry:{e:'open',m:'flat',ch:'#ff9fb8',brow:'angry'}};
function fxFace(p,g,f,blink,form){
  const hx=g.hx,lx=Math.round(hx-(g.hrx*.44)),y0=Math.round(g.ey)-2;let kind=blink&&f.e==='open'?'sleep':f.e;
  const eyes=[[lx-2,'L'],[32-lx-2,'R']];
  eyes.forEach(([x0,side])=>{
    const rows=FX_EYE[kind],oy=kind==='open'?0:kind==='happy'?2:kind==='sleep'?3:kind==='half'?1:1;
    p.pat(x0,y0+oy,rows,{X:FX_DK});
    if(kind==='open'||kind==='half'){p.put(x0+1,y0+oy+1,'#ffffff');if(kind==='open'){p.put(x0+2,y0+oy+3,'#bfe6ff');p.put(x0+1,y0+oy+2,'#4a3a7a')}}
    const b=form==='rebelde'?'angry':f.brow;
    if(b==='sad'){const c=side==='L'?[[0,-1],[1,-2],[2,-2]]:[[3,-1],[2,-2],[1,-2]];c.forEach(a=>p.put(x0+a[0],y0+oy+a[1],FX_DK))}
    if(b==='angry'){const c=side==='L'?[[0,-2],[1,-2],[2,-1],[3,-1]]:[[3,-2],[2,-2],[1,-1],[0,-1]];c.forEach(a=>p.put(x0+a[0],y0+oy+a[1],FX_DK))}
    if(f.tear&&side==='L'){p.put(x0,y0+oy+5,'#8fd3ff');p.put(x0,y0+oy+6,'#8fd3ff')}
  });
  const my=Math.round(g.ey+3.8),cx=hx;
  const M={w:[[-2,0],[-1,1],[0,0],[1,1],[2,0]],o:[[-1,0],[0,0],[-1,1],[0,1]],frown:[[-2,1],[-1,0],[0,0],[1,0],[2,1]],flat:[[-1,0],[0,0],[1,0]],chat:[[-2,0],[-1,1],[0,0],[1,1],[2,0],[3,1]],
    open:[[-1,0],[0,0],[1,0],[-1,1],[0,1],[1,1]],tongue:[[-1,0],[0,0],[1,0]],sick:[[-2,1],[-1,0],[0,1],[1,0],[2,1]]};
  (M[f.m]||M.w).forEach(a=>p.put(cx+a[0],my+a[1],FX_DK));
  if(f.m==='open'){p.put(cx,my+1,'#ff7fa3')}if(f.m==='tongue'){p.put(cx,my+1,'#ff7fa3');p.put(cx,my+2,'#ff7fa3');p.put(cx+1,my+1,'#ff7fa3')}
  if(f.m==='sick'){for(let i=0;i<5;i++)p.put(cx+3+i,my-i*.8+1,i===4?'#ff5a5a':'#ffffff');p.put(cx+7,my-3,'#ff5a5a')}
  const cxL=Math.round(hx-g.hrx*.72)-1;[[cxL,my-1],[32-cxL-3,my-1]].forEach(([x,y])=>{p.rect(x,y,2.6,1.6,f.ch,false)});
  if(f.sweat)p.pat(Math.round(hx+g.hrx*.8),Math.round(g.hy-g.hry*.4),['.X','XX','XX','.X'].map(r=>r),{X:'#8fd3ff'});
  if(f.snow){p.pat(2,6,['.X.','XXX','.X.'],{X:'#d7f0ff'});p.pat(27,10,['.X.','XXX','.X.'],{X:'#d7f0ff'})}
  if(f.stink)[[3,12],[27,15],[5,17]].forEach(a=>{p.put(a[0],a[1],'#9bd16b');p.put(a[0]+1,a[1]+1,'#9bd16b');p.put(a[0],a[1]+2,'#9bd16b')});
  if(f.heart)p.pat(25,3,['.X.X.','XXXXX','XXXXX','.XXX.','..X..'],{X:'#ff6b9a'});
  if(f.z){p.pat(24,7,['XXX','..X','.X.','XXX'],{X:'#bfe0ff'});p.pat(20,3,['XX','.X','XX'],{X:'#e8f4ff'})}
  if(f.halo){p.ell(hx,g.hy-g.hry-2.4,5.4,1.8,'#ffe680',FX_OL)}
}
/* ---- acessórios ---- */
function fxWear(p,g,w,stage){
  const hx=g.hx,top=g.hy-g.hry,lx=Math.round(hx-(g.hrx*.44));
  if(w==='laco'){p.ell(hx+g.hrx*.52-2,top+2.6,2.6,2,sh('#ff6fa8'));p.ell(hx+g.hrx*.52+2.4,top+2.6,2.6,2,sh('#ff6fa8'));p.rect(hx+g.hrx*.52-.4,top+1.8,1.8,1.8,'#c2306f',true)}
  if(w==='oculos'){const y=Math.round(g.ey)-1;p.rect(lx-3,y,6,3.6,'#1b1630',true);p.rect(32-lx-3,y,6,3.6,'#1b1630',true);p.rect(lx+3,y+1,32-2*lx-6,1,'#1b1630',false);p.put(lx-2,y+1,'#6d7bd8');p.put(32-lx-2,y+1,'#6d7bd8')}
  if(w==='cartola'){p.rect(hx-4.2,top-5.4,8.4,5.4,'#2a2438',true);p.rect(hx-4.2,top-1.4,8.4,1.2,'#c0392b',false);p.rect(hx-6.6,top-.2,13.2,1.8,'#2a2438',true)}
  if(w==='cachecol'){const y=g.hy+g.hry-2.2;p.rect(hx-g.hrx*.62,y,g.hrx*1.24,3,'#d94a4a',true);for(let i=0;i<4;i++)p.rect(hx-g.hrx*.62+2+i*4,y+.4,1,2.2,'#ffffff',false);p.rect(hx+g.hrx*.3,y+2.4,3,5,'#d94a4a',true)}
  if(w==='coroa'){const y=top-4;p.rect(hx-5,y+2.4,10,2.6,sh('#ffd13b'),true);[-4.2,0,4.2].forEach(d=>p.tri([hx+d-1.8,y+2.8],[hx+d,y-.4],[hx+d+1.8,y+2.8],sh('#ffd13b')));p.put(hx,y+3.4,'#ff4d6d');p.put(hx-3.6,y+3.6,'#6cc8ff');p.put(hx+3.6,y+3.6,'#6cc8ff')}
}
function fxElder(p,g,stage,f){
  const hx=g.hx,top=g.hy-g.hry,lx=Math.round(hx-(g.hrx*.44)),my=Math.round(g.ey+3.8);
  [lx-2,32-lx-2].forEach(x0=>{[0,1,2].forEach(i=>p.put(x0+i,Math.round(g.ey)-4,'#ffffff'))});
  p.ell(hx,my+2.6,2.8,1.8,'#ffffff',false);[hx-1,hx,hx+1].forEach(x=>p.put(x,top+.5,'#ffffff'));
  if(stage==='elder'){const y=Math.round(g.ey)-3;[lx-3,32-lx-3].forEach(x=>{for(let i=0;i<6;i++){p.put(x+i,y,'#9a8bbd');p.put(x+i,y+5,'#9a8bbd')}for(let j=0;j<6;j++){p.put(x,y+j,'#9a8bbd');p.put(x+5,y+j,'#9a8bbd')}});p.put(hx-1,Math.round(g.ey),'#9a8bbd');p.put(hx,Math.round(g.ey),'#9a8bbd')}
}
/* ---- composição ---- */
function fxCompose(sp,stage,mood,opt){
  opt=opt||{};const g=fxGeo(stage),p=fxPainter(),f=Object.assign({},FX_FACE[mood]||FX_FACE.happy),s={baby:stage==='baby'};
  FX_SP[sp](p,g,s);
  fxFace(p,g,f,opt.blink,opt.form);
  if(stage==='senior'||stage==='elder')fxElder(p,g,stage,f);
  if(opt.wear)fxWear(p,g,opt.wear,stage);
  if(opt.form==='radiante')[[3,6],[28,9],[26,2],[5,24]].forEach(a=>{if(!p.get(a[0],a[1])){p.pat(a[0]-1,a[1]-1,['.X.','XWX','.X.'],{X:'#ffe680',W:'#ffffff'})}});
  return {p,f};
}
function fxPaint(ctx,p,f,opt){
  opt=opt||{};const gray=f.gray,tint=f.tint,sil=opt.sil,elder=opt.stage==='elder';
  for(let y=0;y<p.H;y++)for(let x=0;x<p.W;x++){let c=p.g[y][x];if(!c)continue;
    if(sil)c='#1b1630';else{
      if(gray){const v=fxHex(c),a=(v[0]*.3+v[1]*.59+v[2]*.11);c=fxMix(fxRgb([a,a,a]),'#ffffff',.25)}
      if(tint&&c!==FX_OL&&c!==FX_DK)c=fxMix(c,tint[0],tint[1]);
      if(opt.form==='rebelde'&&c!==FX_OL&&c!==FX_DK)c=fxMix(c,'#2a1b3d',.14);
      if(elder&&c!==FX_OL&&c!==FX_DK)c=fxMix(c,'#9a98a8',.18)}
    ctx.fillStyle=c;ctx.fillRect(x,y,1,1)}
}
const FX_CACHE=new Map();
/* devolve dataURL de uma folha de 2 quadros (olhos abertos / piscando) */
function fxSheet(sp,stage,mood,opt){
  opt=opt||{};const key=[sp,stage,mood,opt.wear||'',opt.form||'',opt.sil?1:0].join('|');if(FX_CACHE.has(key))return FX_CACHE.get(key);
  const cv=document.createElement('canvas');cv.width=FXW*2;cv.height=FXH;const ctx=cv.getContext('2d');
  for(let i=0;i<2;i++){const {p,f}=fxCompose(sp,stage,mood,{wear:opt.wear,form:opt.form,blink:i===1});ctx.save();ctx.translate(i*FXW,0);fxPaint(ctx,p,f,{sil:opt.sil,form:opt.form,stage});ctx.restore()}
  const u=cv.toDataURL('image/png');FX_CACHE.set(key,u);return u;
}
/* ---- ovo ---- */
const FX_EGGS=['#ffd1e1','#cfe9ff','#e2d4ff','#d3f5df','#fff0b8','#ffdcc0'];
function fxEggSheet(seed,warm){
  const key='egg|'+seed+'|'+(warm>=90?2:warm>=60?1:0);if(FX_CACHE.has(key))return FX_CACHE.get(key);
  const cv=document.createElement('canvas');cv.width=FXW*2;cv.height=FXH;const ctx=cv.getContext('2d');
  for(let i=0;i<2;i++){
    const p=fxPainter(),base=FX_EGGS[seed%FX_EGGS.length],sp=fxMix(base,'#3b2457',.28),B=sh(base);
    p.ell(16,22.5,10,12.5,B);
    [[11,16,2],[20,20,2.4],[14,27,2.2],[22,13,1.6],[9,23,1.4]].forEach(a=>p.ell(a[0],a[1],a[2],a[2]*.8,[sp,sp,sp],false));
    p.pat(11,13,['XX','X.'],{X:'#ffffff'});
    const lv=warm>=90?2:warm>=60?1:0;
    if(lv>=1)[[16,11],[17,12],[16,13],[15,14],[16,15],[17,16],[18,17]].forEach(a=>p.put(a[0],a[1],FX_OL));
    if(lv>=2){[[12,17],[13,18],[14,19],[13,20],[19,18],[20,19],[21,20]].forEach(a=>p.put(a[0],a[1],FX_OL));p.pat(14,12,['.XX.','XWWX','XWDX','.XX.'],{X:FX_OL,W:'#ffffff',D:FX_DK})}
    ctx.save();ctx.translate(i*FXW,0);for(let y=0;y<FXH;y++)for(let x=0;x<FXW;x++){const c=p.g[y][x];if(c){ctx.fillStyle=c;ctx.fillRect(x,y,1,1)}}ctx.restore();
  }
  const u=cv.toDataURL('image/png');FX_CACHE.set(key,u);return u;
}
/* ---- cocô e ícones (16x16) ---- */
function fxSmall(key,draw,W,H){
  if(FX_CACHE.has(key))return FX_CACHE.get(key);const cv=document.createElement('canvas');cv.width=W;cv.height=H;const ctx=cv.getContext('2d'),p=fxPainter(W,H);draw(p);
  for(let y=0;y<H;y++)for(let x=0;x<W;x++){const c=p.g[y][x];if(c){ctx.fillStyle=c;ctx.fillRect(x,y,1,1)}}
  const u=cv.toDataURL('image/png');FX_CACHE.set(key,u);return u;
}
const FX_ICON={
 racao:p=>{p.ell(8,8,5.2,4.4,sh('#d8613a'));p.ell(5.5,7,1.6,1.3,'#ffb78a',false);p.rect(11,5,4,2,'#fff3dd',true);p.ell(14.6,5,1.5,1.5,'#fff3dd');p.ell(14.6,8,1.5,1.5,'#fff3dd')},
 fruta:p=>{p.ell(8,9.4,5.6,5.2,sh('#e8433f'));p.rect(7.4,2.4,1.4,3,'#6a4326',false);p.tri([8.6,3.2],[12.4,2],[10.6,5.4],sh('#5fc24a'));p.pat(5,7,['XX','X.'],{X:'#ffffff'})},
 banquete:p=>{p.rect(2,8,12,6,sh('#f7a8c8'),true);p.rect(2,6.4,12,3,'#fff3f8',true);p.ell(8,4.8,1.6,1.6,sh('#e8433f'));p.rect(5,10,1,1,'#fff3f8',false);p.rect(10,11,1,1,'#fff3f8',false)},
 agua:p=>{p.tri([8,1.2],[3.4,9],[12.6,9],sh('#4db8ff'));p.ell(8,10,4.8,4.2,sh('#4db8ff'));p.pat(5,8,['X','X'],{X:'#ffffff'})},
 brincar:p=>{p.ell(8,8,6,6,sh('#ff6b6b'));p.rect(2.2,7.4,11.6,1.8,'#ffffff',false);p.pat(4,4,['XX','X.'],{X:'#ffffff'})},
 passear:p=>{p.rect(7,9,2.4,5.6,'#8b5a2b',true);p.ell(8,6,5.6,5,sh('#52c26a'));p.pat(5,3,['XX','X.'],{X:'#b8f2c0'})},
 carinho:p=>{p.ell(5.4,6,3.6,3.2,sh('#ff5d8f'));p.ell(10.6,6,3.6,3.2,sh('#ff5d8f'));p.tri([2.2,8],[13.8,8],[8,14.4],sh('#ff5d8f'));p.pat(4,4,['XX'],{X:'#ffd1e1'})},
 banho:p=>{p.ell(5.4,9,3.6,3.6,['#e8f8ff','#bfeaff','#8ccdf0']);p.ell(11,6,3,3,['#e8f8ff','#bfeaff','#8ccdf0']);p.ell(10.4,11.8,2.2,2.2,['#e8f8ff','#bfeaff','#8ccdf0']);p.pat(3,7,['X'],{X:'#ffffff'})},
 limpar:p=>{p.rect(7.4,1,1.6,8,'#8b5a2b',true);p.rect(3.6,9,9,5,sh('#e8b84a'),true);p.rect(5,11,1,3,'#b98a2c',false);p.rect(8,11,1,3,'#b98a2c',false);p.rect(11,11,1,3,'#b98a2c',false)},
 cobertor:p=>{p.rect(1.6,3.6,12.8,9,sh('#6ab0f2'),true);for(let i=0;i<3;i++)p.rect(1.6,5.6+i*3,12.8,1,'#ffffff',false);},
 gelo:p=>{p.rect(3,3,10,10,['#e6f8ff','#b4e6ff','#7cc6ee'],true);p.pat(4,4,['XXX','X..'],{X:'#ffffff'});p.pat(8,9,['X.X','.X.'],{X:'#ffffff'})},
 remedio:p=>{p.rect(1.6,4.4,12.8,6.8,'#f1f1f8',true);p.rect(1.6,4.4,6.4,6.8,'#ff6b6b',true);p.pat(3,5.4,['XX'],{X:'#ffc2c2'})},
 casinha:p=>{p.rect(2.6,7.6,10.8,7,sh('#f2c48b'),true);p.tri([1,8],[15,8],[8,1.4],sh('#d9534f'));p.rect(6.6,10.4,3,4.2,'#6a4326',true)},
 bola:p=>FX_ICON.brincar(p),cama:p=>{p.rect(1.6,8,12.8,5,sh('#9b8cf2'),true);p.rect(1.6,5.6,5,3.4,'#ffffff',true);p.rect(1.6,13,1.6,2,'#6a4326',false);p.rect(12.8,13,1.6,2,'#6a4326',false)},
 laco:p=>{p.ell(5,8,3.6,2.8,sh('#ff6fa8'));p.ell(11,8,3.6,2.8,sh('#ff6fa8'));p.rect(7,6.6,2.4,2.8,'#c2306f',true)},
 oculos:p=>{p.rect(1.4,5,6,4.4,'#1b1630',true);p.rect(8.6,5,6,4.4,'#1b1630',true);p.rect(7,6,2,1.2,'#1b1630',false);p.put(2.6,6.4,'#6d7bd8');p.put(9.8,6.4,'#6d7bd8')},
 cartola:p=>{p.rect(4.4,2,7.2,7.6,'#2a2438',true);p.rect(4.4,7,7.2,1.2,'#c0392b',false);p.rect(1.6,9.2,12.8,2.4,'#2a2438',true)},
 cachecol:p=>{p.rect(1.6,4,12.8,3.4,'#d94a4a',true);for(let i=0;i<4;i++)p.rect(3+i*3.4,4.4,1,2.6,'#ffffff',false);p.rect(9.6,6.6,3.6,7,'#d94a4a',true)},
 coroa:p=>{p.rect(2,8,12,4,sh('#ffd13b'),true);[3.6,8,12.4].forEach(x=>p.tri([x-2.4,8.4],[x,2.4],[x+2.4,8.4],sh('#ffd13b')));p.put(8,10,'#ff4d6d');p.put(4.4,10,'#6cc8ff');p.put(11.6,10,'#6cc8ff')},
 poop:p=>{p.ell(8,12,5.4,2.6,sh('#9a6a3a'));p.ell(8,8.6,4,2.6,sh('#9a6a3a'));p.ell(8,5.4,2.4,2,sh('#9a6a3a'));p.put(6,9,FX_DK);p.put(10,9,FX_DK);p.put(6,12,FX_DK);p.put(10,12,FX_DK)}
};
const fxIcon=(k,px)=>'<img class="fxi" alt="" src="'+fxSmall('ic|'+k,FX_ICON[k],16,16)+'" width="'+(16*(px||2))+'" height="'+(16*(px||2))+'">';
/* ---- HTML ---- */
function fxHTML(sp,stage,mood,opt){
  opt=opt||{};const u=fxSheet(sp,stage,mood,opt),px=opt.px||5,calm=mood==='sleep'||mood==='dead'||opt.sil;
  return '<div class="fx'+(calm?' calm':'')+(opt.cls?' '+opt.cls:'')+'" style="width:'+(FXW*px)+'px;height:'+(FXH*px)+'px;background-image:url('+u+')" role="img" aria-label="'+(opt.label||'Faxinho')+'"></div>';
}
function fxEggHTML(seed,warm,px){px=px||5;return '<div class="fx egg'+(warm>=60?' crack':'')+'" style="width:'+(FXW*px)+'px;height:'+(FXH*px)+'px;background-image:url('+fxEggSheet(seed,warm)+')" role="img" aria-label="Ovo misterioso"></div>'}
