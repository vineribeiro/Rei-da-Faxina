const {test,before,after}=require('node:test');
const assert=require('node:assert/strict');
const {PGlite}=require('@electric-sql/pglite');
const fs=require('node:fs');
let db;const uid='11111111-1111-4111-8111-111111111111';
async function q(sql,args=[]){return (await db.query(sql,args)).rows}
async function act(action,value='',key=crypto.randomUUID()){return (await q('select public.pet_action($1,$2,$3) r',[action,value,key]))[0].r}
before(async()=>{
 db=new PGlite();await db.exec(`create role anon;create role authenticated;create schema auth;create schema storage;
 create table auth.users(id uuid primary key,email text,raw_user_meta_data jsonb);
 create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
 create table storage.buckets(id text primary key,name text,public boolean);
 create table storage.objects(id uuid default gen_random_uuid(),bucket_id text,name text);
 alter table storage.objects enable row level security;
 create function storage.foldername(text) returns text[] language sql as $$select string_to_array($1,'/')$$;
 grant usage on schema auth,storage to authenticated,anon;
 grant select,insert,delete on storage.objects to authenticated;`);
 await db.exec(fs.readFileSync('supabase/schema.sql','utf8'));
 await db.exec(fs.readFileSync('supabase/audit-upgrade.sql','utf8'));
 await db.exec(`alter table auth.users disable trigger on_auth_user_created;
 insert into auth.users(id,email,raw_user_meta_data) values('${uid}','test@example.test','{}');
 insert into profiles(id,name) values('${uid}','Teste');
 select set_config('request.jwt.claim.sub','${uid}',false);
 insert into wallet_tx(user_id,type,amount) values('${uid}','earn',500);`);
});
after(async()=>{if(db)await db.close()});
test('SQL upgrade is repeatable and preserves data',async()=>{
 await db.exec(fs.readFileSync('supabase/audit-upgrade.sql','utf8'));
 assert.equal((await q('select balance_of(auth.uid()) b'))[0].b,500);
});
test('legacy state endpoint cannot be used by a player',async()=>{
 assert.equal((await q("select has_function_privilege('authenticated','public.pet_save(jsonb,integer,text)','execute') allowed"))[0].allowed,false);
 await assert.rejects(()=>q("select pet_save('{}',0,'')"),/Atualize/);
});
test('adoption, server cost, owned inventory and idempotency',async()=>{
 assert.equal((await act('adopt')).cost,0);
 await assert.rejects(()=>act('adopt'),/já tem/);
 const key=crypto.randomUUID();assert.equal((await act('buy','coroa',key)).cost,80);
 await act('buy','coroa',key);
 assert.equal((await q('select balance_of(auth.uid()) b'))[0].b,420);
 await assert.rejects(()=>act('buy','coroa'),/já tem/);
 await assert.rejects(()=>act('buy','bola',key),/Identificador/);
 await assert.rejects(()=>act('wear','cartola'),/não adquirido/);
 await assert.rejects(()=>act('buy','invented'),/inválido/);
 await assert.rejects(()=>act('revive'),/prazo/);
});
test('server cooldown cannot be bypassed with another request id',async()=>{
 await act('warm');await assert.rejects(()=>act('warm'),/15 minutos/);
 await act('name','Meu pet');
 const p=(await q('select data from pets where id=auth.uid()'))[0].data;
 assert.equal(p.cur.name,'Meu pet');assert.ok(p.own.includes('coroa'));assert.ok(p.cur.warm>=10&&p.cur.warm<10.01);
});
test('tick hatches, ages and retires without accepting client state',async()=>{
 await db.exec("update pets set data=jsonb_set(data,'{cur,warm}','100')");await act('tick');
 let p=(await q('select data from pets where id=auth.uid()'))[0].data;assert.equal(p.cur.stage,'baby');assert.ok(p.cur.species);
 await db.exec("update pets set data=jsonb_set(data,'{cur,hatchedAt}',to_jsonb(extract(epoch from now())*1000-63*86400000.0))");
 await act('tick');p=(await q('select data from pets where id=auth.uid()'))[0].data;
 assert.equal(p.cur.stage,'egg');assert.equal(p.cur.bonus,true);
});
test('anonymous and inactive users cannot use privileged operations',async()=>{
 await db.exec("select set_config('request.jwt.claim.sub','',false)");await assert.rejects(()=>act('adopt'),/jogadores/);
 await db.exec(`select set_config('request.jwt.claim.sub','${uid}',false);update profiles set active=false where id=auth.uid()`);
 await assert.rejects(()=>act('tick'),/jogadores/);
 await db.exec('update profiles set active=true where id=auth.uid()');
});
test('versions change only for the modified tables',async()=>{
 const a=(await q('select sync_versions() v'))[0].v;
 await db.exec("update profiles set name='Teste 2' where id=auth.uid()");const b=(await q('select sync_versions() v'))[0].v;
 assert.notEqual(a.profiles,b.profiles);assert.equal(a.wallet_tx,b.wallet_tx);
 await db.exec("update app_secrets set house_code='ABCDEF'");const c=(await q('select sync_versions() v'))[0].v;assert.notEqual(b.settings,c.settings);
});
test('proof cleanup never authorizes another user path or a committed proof',async()=>{
 await assert.rejects(()=>q("select abandon_evidence_upload('other/test.jpg')"),/inválido/);
 const path=uid+'/test.jpg';
 assert.equal((await q('select abandon_evidence_upload($1) v',[path]))[0].v,true);
 assert.equal((await q('select can_remove_evidence($1) v',[path]))[0].v,true);
 const per=(await q("select id from periods where status='open' limit 1"))[0].id;
 const cat=(await q('select id from categories limit 1'))[0].id;
 const occ=(await q("insert into occurrences(period_id,title,category_id,points,assigned_to,due_date) values($1,'Teste foto',$2,10,auth.uid(),current_date) returning id",[per,cat]))[0].id;
 await assert.rejects(()=>q('select submit_evidence($1,$2)',[occ,path]),/cancelado/);
 const good=uid+'/good.jpg';await q("insert into storage.objects(bucket_id,name) values('evidence',$1)",[good]);
 await q('select submit_evidence($1,$2)',[occ,good]);
 assert.equal((await q('select abandon_evidence_upload($1) v',[good]))[0].v,false);
 assert.equal((await q('select can_remove_evidence($1) v',[good]))[0].v,false);
 await q('select submit_evidence($1,$2)',[occ,good]);
 assert.equal((await q('select count(*)::int n from evidence where image_path=$1',[good]))[0].n,1);
});
test('authenticated player can use commands but cannot write pet state directly',async()=>{
 await db.exec('set role authenticated');
 try{await act('tick');await assert.rejects(()=>q("update pets set data='{}' where id=auth.uid()"),/permission denied/);await assert.rejects(()=>q('select * from rdf_private.pet_requests'),/permission denied/)}finally{await db.exec('reset role')}
});
test('server enforces care prices, cooldowns and revival deadline',async()=>{
 const hr=(await q("select extract(hour from now() at time zone 'America/Sao_Paulo')::int hr"))[0].hr;
 const species=hr>=7&&hr<22?'pinguim':'coruja';
 async function reset(extra={}){await q(`update pets set data=jsonb_set(data,'{cur}',rdf_private.hatch(rdf_private.egg(extract(epoch from now())*1000,false),extract(epoch from now())*1000)||$1::jsonb) where id=auth.uid()`,[JSON.stringify({species,hunger:40,thirst:40,energy:70,hygiene:30,pf:2,sick:true,cd:{},...extra})])}
 for(const [action,cost] of Object.entries({racao:6,fruta:3,banquete:14,agua:0,brincar:0,passear:2,carinho:0,banho:1,limpar:0,cobertor:6,gelo:6,remedio:15})){
  await reset();assert.equal((await act('care',action)).cost,cost);
 }
 await reset();await act('care','carinho');await assert.rejects(()=>act('care','carinho'),/Aguarde/);
 await reset({dead:Date.now()-73*3600000});await assert.rejects(()=>act('revive'),/prazo/);
 await reset({dead:Date.now()-3600000});assert.equal((await act('revive')).cost,40);
});
