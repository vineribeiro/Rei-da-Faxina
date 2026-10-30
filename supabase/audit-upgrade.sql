-- Apply AFTER schema.sql and the existing feature upgrades. Does not reset game data.
-- Deploy this upgrade BEFORE the new frontend. Run as the database owner in SQL Editor.
begin;
create schema if not exists rdf_private;
revoke all on schema rdf_private from public, anon, authenticated;

-- One small version snapshot replaces repeated downloads of unchanged tables.
create table if not exists rdf_private.versions (name text primary key, version bigint not null default 1);
create or replace function rdf_private.bump_version() returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into rdf_private.versions(name,version) values(tg_table_name,1)
 on conflict(name) do update set version=rdf_private.versions.version+1;
 return null;
end $$;
do $$ declare t text; begin
 foreach t in array array['settings','profiles','categories','catalog','periods','tasks','occurrences','evidence','score_tx','wallet_tx','rewards','redemptions','achievements_unlocked','rest_days','spins','audit_log','pets','app_secrets'] loop
  if to_regclass('public.'||t) is not null then
   insert into rdf_private.versions(name) values(t) on conflict do nothing;
   execute format('drop trigger if exists rdf_version on public.%I',t);
   execute format('create trigger rdf_version after insert or update or delete or truncate on public.%I for each statement execute function rdf_private.bump_version()',t);
  end if;
 end loop;
end $$;
create or replace function public.sync_versions() returns jsonb language plpgsql security definer set search_path='' as $$
declare r jsonb; begin
 perform public.need_member();
 select jsonb_object_agg(name,version::text) into r from rdf_private.versions;
 -- A new house code must invalidate the settings cache, even if only app_secrets changed.
 r:=jsonb_set(r,'{settings}',to_jsonb(coalesce(r->>'settings','0')||':'||coalesce(r->>'app_secrets','0')));
 return r-'app_secrets';
end $$;
revoke all on function public.sync_versions() from public,anon;
grant execute on function public.sync_versions() to authenticated;
create or replace function public.public_status() returns jsonb language sql stable security definer set search_path=public as $$
 select jsonb_build_object('appName',s.app_name,'openSignup',s.open_signup,
 'gameStart',to_jsonb(s)->>'game_start','players',(select count(*) from profiles where active and plays),
 'hasAdmin',exists(select 1 from profiles where role='admin')) from settings s where s.id=1
$$;

-- A cleanup request and evidence submission lock the same path. A response lost after
-- commit can NEVER turn a valid proof into a deleted file.
create table if not exists rdf_private.abandoned_uploads(path text primary key, user_id uuid not null, created_at timestamptz not null default now());
create or replace function public.abandon_evidence_upload(p_path text) returns boolean language plpgsql security definer set search_path='' as $$
begin
 perform public.need_member();
 if p_path is null or length(p_path)>512 or split_part(p_path,'/',1)<>auth.uid()::text then raise exception 'Arquivo inválido.'; end if;
 perform pg_advisory_xact_lock(hashtextextended(p_path,8221));
 if exists(select 1 from public.evidence where image_path=p_path) or exists(select 1 from public.occurrences where photo_path=p_path) then return false; end if;
 insert into rdf_private.abandoned_uploads(path,user_id) values(p_path,auth.uid()) on conflict do nothing;
 return true;
end $$;
create or replace function public.can_remove_evidence(p_path text) returns boolean language sql stable security definer set search_path='' as $$
 select public.is_member() and exists(select 1 from rdf_private.abandoned_uploads where path=p_path and user_id=auth.uid())
 and not exists(select 1 from public.evidence where image_path=p_path)
 and not exists(select 1 from public.occurrences where photo_path=p_path)
$$;
revoke all on function public.abandon_evidence_upload(text),public.can_remove_evidence(text) from public,anon;
grant execute on function public.abandon_evidence_upload(text),public.can_remove_evidence(text) to authenticated;
drop policy if exists "remove only abandoned own uploads" on storage.objects;
create policy "remove only abandoned own uploads" on storage.objects for delete to authenticated
 using(bucket_id='evidence' and public.can_remove_evidence(name));
create or replace function public.submit_evidence(p_occ uuid,p_path text) returns jsonb language plpgsql security definer set search_path=public as $$
declare o occurrences; begin
 perform need_member();
 if coalesce(p_path,'')='' or split_part(p_path,'/',1)<>auth.uid()::text then raise exception 'Foto inválida.'; end if;
 perform pg_advisory_xact_lock(hashtextextended(p_path,8221));
 if exists(select 1 from rdf_private.abandoned_uploads where path=p_path) then raise exception 'Envio cancelado. Escolha a foto novamente.'; end if;
 select * into o from occurrences where id=p_occ for update;
 if not found then raise exception 'Tarefa não encontrada.'; end if;
 if o.assigned_to is distinct from auth.uid() then raise exception 'Só o responsável pode enviar a comprovação.'; end if;
 if o.status='awaiting_approval' and o.photo_path=p_path then return jsonb_build_object('ok',true); end if;
 if o.status not in ('available','in_progress','rejected') then raise exception 'Esta tarefa não aceita novo envio agora.'; end if;
 if not exists(select 1 from periods where id=o.period_id and status='open') then raise exception 'O período desta tarefa foi encerrado.'; end if;
 if not exists(select 1 from storage.objects where bucket_id='evidence' and name=p_path) then raise exception 'O upload da foto não foi concluído.'; end if;
 insert into evidence(occurrence_id,submitted_by,image_path) values(p_occ,auth.uid(),p_path);
 update occurrences set status='awaiting_approval',submitted_by=auth.uid(),submitted_at=now(),photo_path=p_path,rejection_reason='',log=log||log_item('Comprovação enviada') where id=p_occ;
 perform aud('submit','occurrence',p_occ::text,'');return jsonb_build_object('ok',true);
end $$;

-- Pet simulation helpers are private; only pet_action is callable by players.
create or replace function rdf_private.n(s jsonb,k text) returns double precision language sql immutable as $$ select coalesce((s->>k)::double precision,0) $$;
create or replace function rdf_private.add_need(s jsonb,k text,v double precision) returns jsonb language sql immutable as $$
 select jsonb_set(s,array[k],to_jsonb(greatest(0,least(100,rdf_private.n(s,k)+v)))) $$;
create or replace function rdf_private.rnd(seed double precision,n double precision) returns double precision language sql immutable as $$
 select sin(seed*12.9898+n*78.233)*43758.5453-floor(sin(seed*12.9898+n*78.233)*43758.5453) $$;
create or replace function rdf_private.egg(t double precision,bonus boolean) returns jsonb language sql volatile as $$
 select jsonb_build_object('seed',floor(random()*1000000)+1,'stage','egg','species',null,'name','','named',false,'bornAt',t,'t',t,'warm',0,'bonus',bonus,'cd','{}'::jsonb,'low','{}'::jsonb,'mistakes',0,'hunger',90,'thirst',90,'fun',90,'energy',90,'hygiene',100,'love',80,'temp',50,'health',100,'sick',false,'pf',0,'digest',0,'buff',null,'form',null,'dead',null,'retired',null,'hatchedAt',null) $$;
create or replace function rdf_private.hatch(s jsonb,t double precision) returns jsonb language plpgsql immutable as $$
declare r double precision:=rdf_private.rnd(rdf_private.n(s,'seed'),7); bonus boolean:=coalesce((s->>'bonus')::boolean,false); pool text[]; species text; nm text;
begin
 if r<.10+(case when bonus then .08 else 0 end) then pool:=array['dragao','unicornio'];
 elsif r<.45+(case when bonus then .20 else 0 end) then pool:=array['coruja','raposa','polvo','morcego'];
 else pool:=array['pinguim','lagarto','panda','coelho']; end if;
 species:=pool[1+floor(rdf_private.rnd(rdf_private.n(s,'seed'),11)*cardinality(pool))::int];
 nm:=('{"dragao":"Dragãozinho Brasa","unicornio":"Unicórnio Aurora","coruja":"Coruja Lunar","raposa":"Raposa Ruiva","polvo":"Polvo Marujo","morcego":"Morcego Noturno","pinguim":"Pinguim Gelado","lagarto":"Lagartixa Solar","panda":"Panda Soneca","coelho":"Coelho Pulinho"}'::jsonb)->>species;
 return s||jsonb_build_object('stage','baby','species',species,'hatchedAt',t,'t',t,'hunger',85,'thirst',85,'fun',85,'energy',90,'hygiene',100,'love',90,'temp',50,'health',100,'name',coalesce(nullif(s->>'name',''),nm));
end $$;
create or replace function rdf_private.sleeping(species text,hr double precision) returns boolean language sql immutable as $$
 select case species when 'coruja' then hr>=7 and hr<16 when 'morcego' then hr>=8 and hr<17 when 'panda' then hr>=21 or hr<8 when 'lagarto' then hr>=21 or hr<6 else hr>=22 or hr<7 end $$;
create or replace function rdf_private.tick(s jsonb,tn double precision,own jsonb) returns jsonb language plpgsql as $$
declare t double precision; dt double precision; hr double precision; age double precision; mult double precision; sm double precision; dg double precision; tg double precision; dev double precision; pref double precision; crit int; sp text; sg text; sleeping boolean; k text; val double precision; conds jsonb; risk double precision;
begin
 if s->>'dead' is not null or s->>'retired' is not null then return s||jsonb_build_object('t',tn); end if;
 if s->>'stage'='egg' and rdf_private.n(s,'warm')>=100 then s:=rdf_private.hatch(s,tn); end if;
 t:=greatest(rdf_private.n(s,'t'),tn-45*86400000.0);
 while t<tn loop
 dt:=least(1800000,tn-t)/3600000.0;t:=t+dt*3600000;
 if s->>'stage'='egg' then s:=rdf_private.add_need(s,'warm',.5*dt);if rdf_private.n(s,'warm')>=100 then s:=rdf_private.hatch(s,t);end if;continue;end if;
 sp:=s->>'species';hr:=extract(hour from to_timestamp(t/1000) at time zone 'America/Sao_Paulo')+extract(minute from to_timestamp(t/1000) at time zone 'America/Sao_Paulo')/60.0;
 sleeping:=rdf_private.sleeping(sp,hr);age:=(t-rdf_private.n(s,'hatchedAt'))/86400000.0;
 if age>=62 then s:=s||jsonb_build_object('retired',t,'stage','retired');exit;end if;
 sg:=case when age>=48 then 'elder' when age>=27 then 'senior' when age>=13 then 'adult' when age>=6 then 'teen' when age>=2 then 'child' else 'baby' end;
 mult:=case sg when 'baby' then 1.4 when 'child' then 1.15 when 'adult' then .9 when 'senior' then .9 when 'elder' then 1.1 else 1 end;
 if sg='adult' and s->>'form' is null then s:=s||jsonb_build_object('form',case when rdf_private.n(s,'mistakes')<=3 then 'radiante' when rdf_private.n(s,'mistakes')<=10 then 'normal' else 'rebelde' end);end if;
 s:=s||jsonb_build_object('stage',sg);sm:=case when sleeping then .35 else 1 end;
 s:=rdf_private.add_need(s,'hunger',-2.6*mult*sm*dt);
 s:=rdf_private.add_need(s,'thirst',-3.2*(case when sp='polvo' then 1.4 else 1 end)*mult*sm*dt);
 s:=rdf_private.add_need(s,'fun',-2.4*(case when sp='raposa' then 1.2 when sp='coelho' then 1.4 else 1 end)*mult*sm*dt);
 s:=rdf_private.add_need(s,'energy',(case when sleeping then 9*(case when own?'cama' then 1.4 else 1 end) else -2*(case when sp='panda' then 1.4 else 1 end)*mult end)*dt);
 s:=rdf_private.add_need(s,'hygiene',-(1.2+3*floor(rdf_private.n(s,'pf')))*sm*dt);
 s:=rdf_private.add_need(s,'love',-1.4*(case when sleeping then .3 else 1 end)*dt);
 dg:=least(rdf_private.n(s,'digest'),15*dt);s:=s||jsonb_build_object('digest',rdf_private.n(s,'digest')-dg,'pf',rdf_private.n(s,'pf')+dg/50);
 pref:=coalesce(('{"dragao":15,"unicornio":0,"coruja":-4,"raposa":3,"polvo":-6,"morcego":-8,"pinguim":-15,"lagarto":12,"panda":-3,"coelho":0}'::jsonb->>sp)::double precision,0);
 tg:=50+28*sin((hr-9)/24*2*pi())-pref;
 if t<coalesce((s#>>'{buff,until}')::double precision,0) then tg:=tg+(s#>>'{buff,v}')::double precision;end if;
 if own?'casinha' then tg:=50+(tg-50)*.5;end if;
 s:=rdf_private.add_need(s,'temp',(tg-rdf_private.n(s,'temp'))*(1-exp(-.5*dt)));dev:=abs(rdf_private.n(s,'temp')-50);
 conds:=jsonb_build_object('hunger',rdf_private.n(s,'hunger')<=12,'thirst',rdf_private.n(s,'thirst')<=12,'fun',rdf_private.n(s,'fun')<=12,'energy',not sleeping and rdf_private.n(s,'energy')<=12,'hygiene',rdf_private.n(s,'hygiene')<=12 or rdf_private.n(s,'pf')>=3,'love',rdf_private.n(s,'love')<=12,'temp',dev>35);
 crit:=(rdf_private.n(s,'hunger')<=8)::int+(rdf_private.n(s,'thirst')<=8)::int+(dev>38)::int+(not sleeping and rdf_private.n(s,'energy')<=8)::int+(rdf_private.n(s,'pf')>=4 or rdf_private.n(s,'hygiene')<=8)::int;
 for k in select jsonb_object_keys(conds) loop
 val:=coalesce((s#>>array['low',k])::double precision,0);
 if val<0 then val:=least(0,val+dt*60);
 elsif (conds->>k)::boolean and not sleeping then val:=val+dt*60;if val>=120 then s:=s||jsonb_build_object('mistakes',rdf_private.n(s,'mistakes')+1);val:=-180;end if;
 else val:=0;end if;
 s:=jsonb_set(s,array['low',k],to_jsonb(val));
 end loop;
 if not coalesce((s->>'sick')::boolean,false) then
 risk:=.003+case when rdf_private.n(s,'hygiene')<20 then .04 else 0 end+case when rdf_private.n(s,'pf')>=3 then .05 else 0 end+case when dev>38 then .05 else 0 end+case when rdf_private.n(s,'health')<40 then .03 else 0 end;
 if rdf_private.rnd(rdf_private.n(s,'seed'),floor(t/1800000))<risk*dt*2 then s:=s||jsonb_build_object('sick',true,'sickAt',t);end if;
 end if;
 s:=rdf_private.add_need(s,'health',(case when (s->>'sick')::boolean then -3 when crit>0 then -.6*crit else 2 end)*dt);
 if rdf_private.n(s,'health')<=0 then s:=s||jsonb_build_object('dead',t);exit;end if;
 end loop;
 return s||jsonb_build_object('t',tn);
end $$;
create table if not exists rdf_private.pet_requests(user_id uuid not null, request_id uuid not null, action text not null, value text not null, result jsonb not null, created_at timestamptz not null default now(), primary key(user_id,request_id));
create or replace function public.pet_action(p_action text,p_value text default '',p_key uuid default gen_random_uuid()) returns jsonb language plpgsql security definer set search_path='' as $$
declare p jsonb; s jsonb; old jsonb; own jsonb; tn double precision:=extract(epoch from now())*1000; cost int:=0; cd int:=0; hr double precision; result jsonb; prev rdf_private.pet_requests; it text; gain jsonb; k text; prices jsonb:='{"casinha":60,"bola":15,"cama":40,"laco":12,"oculos":20,"cartola":30,"cachecol":25,"coroa":80}';
begin
 if not public.player_ok(auth.uid()) then raise exception 'Apenas jogadores têm Faxinho.';end if;
 if p_key is null or p_action is null or p_value is null or length(p_value)>80 then raise exception 'Comando inválido.';end if;
 perform 1 from public.profiles where id=auth.uid() for update;
 select * into prev from rdf_private.pet_requests where user_id=auth.uid() and request_id=p_key;
 if found then
  if prev.action<>p_action or prev.value<>p_value then raise exception 'Identificador de operação já usado.';end if;
  return prev.result;
 end if;
 select data into p from public.pets where id=auth.uid() for update;
 p:=coalesce(p,'{"own":[],"album":{},"wear":null}'::jsonb);own:=coalesce(p->'own','[]'::jsonb);old:=p->'cur';s:=old;
 if s is not null and s<>'null'::jsonb then
  s:=rdf_private.tick(s,tn,own);
  if old->>'stage'='egg' and s->>'stage'<>'egg' then
   it:=s->>'species';p:=jsonb_set(p,array['album',it],jsonb_build_object('n',coalesce((p#>>array['album',it,'n'])::int,0)+1,'best',coalesce((p#>>array['album',it,'best'])::int,0)));
  end if;
  if s->>'retired' is not null then
   it:=s->>'species';p:=jsonb_set(p,array['album',it],jsonb_build_object('n',coalesce((p#>>array['album',it,'n'])::int,1),'best',62,'form',s->>'form'));
   s:=rdf_private.egg(tn,true);
  end if;
 end if;
 if p_action='adopt' then
  if s is not null and s<>'null'::jsonb then raise exception 'Você já tem um Faxinho.';end if;
  s:=rdf_private.egg(tn,false);
 elsif p_action='egg' then
  if s is null or s->>'dead' is null then raise exception 'Cuide do seu Faxinho atual.';end if;
  cost:=20;s:=rdf_private.egg(tn,false);
 elsif p_action='tick' then
  if s is null then raise exception 'Adote um Faxinho primeiro.';end if;
 elsif p_action='buy' then
  if s is null or not prices?p_value then raise exception 'Item inválido.';end if;
  if own?p_value then raise exception 'Você já tem esse item.';end if;
  cost:=(prices->>p_value)::int;own:=own||to_jsonb(p_value);
  if p_value not in ('casinha','bola','cama') then p:=p||jsonb_build_object('wear',p_value);end if;
 elsif p_action='wear' then
  if not own?p_value or p_value in ('casinha','bola','cama') then raise exception 'Acessório não adquirido.';end if;
  p:=p||jsonb_build_object('wear',case when p->>'wear'=p_value then null else p_value end);
 elsif p_action='name' then
  if s is null or length(btrim(p_value)) not between 2 and 16 then raise exception 'Use um nome com 2 a 16 caracteres.';end if;
  s:=s||jsonb_build_object('name',btrim(p_value),'named',true);
 elsif p_action='revive' then
  if s->>'dead' is null or tn-rdf_private.n(s,'dead')>72*3600000.0 then raise exception 'O prazo para reviver terminou ou o Faxinho está vivo.';end if;
  cost:=40;s:=s||jsonb_build_object('dead',null,'health',40,'hunger',50,'thirst',50,'fun',50,'energy',60,'hygiene',60,'love',50,'temp',50,'sick',false,'pf',0,'t',tn,'low','{}'::jsonb,'mistakes',rdf_private.n(s,'mistakes')+3);
 elsif p_action='warm' then
  if s->>'stage' is distinct from 'egg' then raise exception 'Só ovos podem ser aquecidos.';end if;
  if tn-coalesce((s#>>'{cd,warm}')::double precision,0)<900000 then raise exception 'O ovo já está quentinho. Aguarde 15 minutos.';end if;
  s:=rdf_private.add_need(s,'warm',10);s:=jsonb_set(s,'{cd,warm}',to_jsonb(tn));
 elsif p_action='care' then
  if s is null or s->>'stage'='egg' or s->>'dead' is not null then raise exception 'Este Faxinho não pode receber esse cuidado.';end if;
  hr:=extract(hour from now() at time zone 'America/Sao_Paulo');
  if rdf_private.sleeping(s->>'species',hr) and p_value not in ('cobertor','gelo','remedio','limpar') then raise exception 'Shhh... está dormindo. Volte mais tarde.';end if;
  cd:=case p_value when 'brincar' then 20 when 'passear' then 60 when 'carinho' then 15 when 'banho' then 120 else 0 end;
  if cd>0 and tn-coalesce((s#>>array['cd',p_value])::double precision,0)<cd*60000 then raise exception 'Aguarde antes de repetir esse cuidado.';end if;
  case p_value
   when 'racao' then if rdf_private.n(s,'hunger')>=92 then raise exception 'Está de barriguinha cheia.';end if;cost:=6;gain:='{"hunger":30}';s:=s||jsonb_build_object('digest',rdf_private.n(s,'digest')+30);
   when 'fruta' then if rdf_private.n(s,'hunger')>=92 then raise exception 'Está de barriguinha cheia.';end if;cost:=3;gain:='{"hunger":16,"love":3}';s:=s||jsonb_build_object('digest',rdf_private.n(s,'digest')+14);
   when 'banquete' then if rdf_private.n(s,'hunger')>=85 then raise exception 'Sem espaço para um banquete agora.';end if;cost:=14;gain:='{"hunger":50,"fun":12}';s:=s||jsonb_build_object('digest',rdf_private.n(s,'digest')+60);
   when 'agua' then if rdf_private.n(s,'thirst')>=92 then raise exception 'Já bebeu o suficiente.';end if;gain:='{"thirst":40}';
   when 'brincar' then if rdf_private.n(s,'energy')<15 then raise exception 'Está cansado demais para brincar.';end if;gain:=jsonb_build_object('fun',case when own?'bola' then 35 else 20 end,'energy',-8,'hunger',-3);
   when 'passear' then if rdf_private.n(s,'energy')<25 then raise exception 'Está cansado demais para passear.';end if;cost:=2;gain:='{"fun":30,"love":8,"energy":-15,"hygiene":-8}';
   when 'carinho' then gain:='{"love":12,"fun":3}';
   when 'banho' then cost:=1;gain:='{"hygiene":50}';s:=s||'{"pf":0}'::jsonb;
   when 'limpar' then if rdf_private.n(s,'pf')<1 then raise exception 'Não tem nada para limpar.';end if;gain:='{"hygiene":10}';s:=s||'{"pf":0}'::jsonb;
   when 'cobertor' then cost:=6;gain:='{"temp":15}';s:=s||jsonb_build_object('buff',jsonb_build_object('v',20,'until',tn+6*3600000));
   when 'gelo' then cost:=6;gain:='{"temp":-15}';s:=s||jsonb_build_object('buff',jsonb_build_object('v',-20,'until',tn+4*3600000));
   when 'remedio' then if not (s->>'sick')::boolean then raise exception 'Não está doente.';end if;cost:=15;gain:='{"health":15}';s:=s||'{"sick":false}'::jsonb;
   else raise exception 'Cuidado inválido.';
  end case;
  for k in select jsonb_object_keys(gain) loop s:=rdf_private.add_need(s,k,(gain->>k)::double precision);end loop;
  if cd>0 then s:=jsonb_set(s,array['cd',p_value],to_jsonb(tn));end if;
 else raise exception 'Comando inválido.';
 end if;
 if cost>0 then
  if public.balance_of(auth.uid())<cost then raise exception 'Moedas insuficientes.';end if;
  insert into public.wallet_tx(user_id,type,amount,ref,reason) values(auth.uid(),'spend',-cost,'pet:'||p_key::text,'Faxinho: '||p_action||' '||p_value);
 end if;
 p:=p||jsonb_build_object('cur',s,'own',own);
 insert into public.pets(id,data,updated_at) values(auth.uid(),p,now()) on conflict(id) do update set data=excluded.data,updated_at=excluded.updated_at;
 result:=jsonb_build_object('ok',true,'cost',cost);
 insert into rdf_private.pet_requests(user_id,request_id,action,value,result) values(auth.uid(),p_key,p_action,p_value,result);
 return result;
end $$;
alter table rdf_private.versions enable row level security;
alter table rdf_private.abandoned_uploads enable row level security;
alter table rdf_private.pet_requests enable row level security;
-- Old clients fail closed instead of preserving an exploitable endpoint.
create or replace function public.pet_save(p_state jsonb,p_spend int,p_reason text) returns jsonb language plpgsql as $$
begin raise exception 'Atualize o Rei da Faxina para cuidar do seu Faxinho com segurança.';end $$;
revoke all on function public.pet_save(jsonb,int,text) from public,anon,authenticated;
revoke all on all functions in schema rdf_private from public,anon,authenticated;
revoke all on all tables in schema rdf_private from public,anon,authenticated;
revoke all on function public.pet_action(text,text,uuid) from public,anon;
grant execute on function public.pet_action(text,text,uuid) to authenticated;
commit;
