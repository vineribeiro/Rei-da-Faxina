-- =====================================================================
-- Rei da Faxina: esquema do Supabase (Postgres + Auth + Storage)
-- Rode UMA vez no SQL Editor de um projeto novo (veja SUPABASE.md).
--
-- Modelo de acesso:
--  * 1 único perfil administrador, definido pelo seu e-mail (veja a linha ">>> TROQUE AQUI <<<" abaixo).
--  * Cada jogador cria o próprio cadastro (e-mail + senha) informando o CÓDIGO DA CASA. Máximo de 4 jogadores.
--  * O app só LÊ as tabelas. Toda escrita passa por funções que validam quem está chamando.
--  * Pontos, moedas, aprovações e resgates nunca são gravados direto pelo navegador.
-- =====================================================================

-- >>> TROQUE AQUI <<< pelo e-mail do administrador (o mesmo que você vai usar para criar a conta no app).
create temp table _cfg as select lower('viniciusribeiroo@hotmail.com') as admin_email;
do $$ begin
  if (select admin_email from _cfg) like '%@exemplo.com' then
    raise exception 'Antes de rodar, troque COLOQUE_SEU_EMAIL_AQUI@exemplo.com pelo e-mail do administrador (linha ">>> TROQUE AQUI <<<").';
  end if;
end $$;

-- ======================= 1. TABELAS ==================================
create table public.settings (
  id int primary key default 1 check (id = 1),
  app_name text not null default 'Rei da Faxina',
  prize numeric(10,2) not null default 50 check (prize >= 0),
  rest_days int not null default 2 check (rest_days between 0 and 10),
  shop_enabled boolean not null default true,
  coin_rate int not null default 1 check (coin_rate between 0 and 10),
  open_signup boolean not null default true,
  tz text not null default 'America/Sao_Paulo',
  penalty jsonb not null default '{"enabled":false,"latePoints":0,"missPoints":0,"maxPerOcc":5,"grace":1}',
  challenges text[] not null default '{}'
);
insert into public.settings (challenges) values (array[
  'Arrume 5 coisas fora do lugar em 5 minutos','Deixe a pia da cozinha vazia hoje',
  'Limpe uma superfície que ninguém lembra de limpar','Organize uma gaveta',
  'Passe um pano na porta da geladeira','Recolha tudo o que está fora do lugar na sala']);

create or replace function public.today_br() returns date language sql stable as $$
  select (now() at time zone coalesce((select tz from public.settings where id = 1), 'America/Sao_Paulo'))::date
$$;

create table public.admin_emails (email text primary key);   -- só o servidor lê (sem política de leitura)
insert into public.admin_emails select admin_email from _cfg;
-- Código que os jogadores digitam ao se cadastrar. O administrador vê e troca em Ajustes. Só o servidor lê a tabela.
create table public.app_secrets (id int primary key default 1 check (id = 1), house_code text not null);
insert into public.app_secrets (house_code) values (upper(substr(md5(random()::text || clock_timestamp()::text), 1, 8)));

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null check (char_length(name) between 2 and 20),
  avatar text not null default '🦊' check (char_length(avatar) <= 12),
  color text not null default '#2B63E8' check (color ~ '^#[0-9A-Fa-f]{6}$'),
  role text not null default 'user' check (role in ('admin','user')),
  plays boolean not null default true,              -- false = só administra (fora do ranking)
  active boolean not null default true,
  title text not null default '',
  unlocked_avatars text[] not null default '{}',
  created_at timestamptz not null default now()
);
create unique index profiles_name_active on public.profiles (lower(name)) where active;

create table public.categories (id text primary key, name text not null, icon text not null default '✨');
create table public.catalog (id text primary key, title text not null, points int not null check (points between 1 and 500),
  category_id text references public.categories(id), freq text not null default 'once');

create table public.periods (
  id uuid primary key default gen_random_uuid(),
  start_date date not null, end_date date not null,
  status text not null default 'open' check (status in ('open','closed')),
  winner_id uuid references public.profiles(id),
  prize_amount numeric(10,2) not null default 0, prize_paid boolean not null default false,
  tie_resolution jsonb, final jsonb,
  closed_at timestamptz, closed_by uuid references public.profiles(id)
);
create unique index one_open_period on public.periods (status) where status = 'open';

create table public.tasks (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(title) between 2 and 80),
  description text not null default '',
  category_id text references public.categories(id),
  frequency text not null check (frequency in ('once','daily','weekly','monthly','custom')),
  interval_days int check (interval_days between 2 and 365),
  points int not null check (points between 1 and 500),
  assigned_to uuid references public.profiles(id),
  next_due date, anchor_day int, active boolean not null default true,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  log jsonb not null default '[]'
);

create table public.occurrences (
  id uuid primary key default gen_random_uuid(),
  task_id uuid references public.tasks(id),
  period_id uuid not null references public.periods(id),
  title text not null, description text not null default '',
  category_id text references public.categories(id),
  points int not null check (points between 1 and 500),
  assigned_to uuid references public.profiles(id),
  due_date date not null,
  status text not null default 'available' check (status in
    ('available','in_progress','awaiting_proof','awaiting_approval','done','rejected','cancelled')),
  recurring boolean not null default false,
  late_pen boolean not null default false, miss_pen boolean not null default false,
  created_at timestamptz not null default now(), completed_at timestamptz,
  submitted_by uuid references public.profiles(id), submitted_at timestamptz,
  reviewed_by uuid references public.profiles(id), reviewed_at timestamptz,
  rejection_reason text not null default '', photo_path text,
  log jsonb not null default '[]',
  unique (task_id, due_date)
);

create table public.evidence (
  id uuid primary key default gen_random_uuid(),
  occurrence_id uuid not null references public.occurrences(id),
  submitted_by uuid not null references public.profiles(id),
  image_path text not null, submitted_at timestamptz not null default now(),
  review_status text not null default 'pending' check (review_status in ('pending','approved','rejected')),
  reviewed_by uuid references public.profiles(id), reviewed_at timestamptz, rejection_reason text not null default ''
);

create table public.score_tx (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id),
  occurrence_id uuid references public.occurrences(id),
  period_id uuid not null references public.periods(id),
  type text not null check (type in ('task','adjust','penalty','reversal')),
  points int not null, reason text not null default '',
  ref_tx uuid, reversed_by uuid, post_close boolean not null default false,
  day date not null default public.today_br(),
  created_by uuid references public.profiles(id), created_at timestamptz not null default now(),
  contest jsonb
);
create unique index one_task_score_per_occurrence on public.score_tx (occurrence_id) where type = 'task';

create table public.wallet_tx (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id),
  type text not null check (type in ('earn','spend','refund','bonus','reversal')),
  amount int not null, ref text, reason text not null default '',
  created_at timestamptz not null default now()
);

create table public.rewards (
  id uuid primary key default gen_random_uuid(),
  name text not null, description text not null default '',
  cost int not null check (cost >= 0), stock int check (stock >= 0),
  kind text not null default 'normal' check (kind in ('normal','avatar','title')),
  payload jsonb not null default '{}', per_user_limit int not null default 0,
  active boolean not null default true
);

create table public.redemptions (
  id uuid primary key default gen_random_uuid(),
  request_key uuid not null unique,
  reward_id uuid not null references public.rewards(id),
  name text not null, user_id uuid not null references public.profiles(id),
  cost int not null, status text not null default 'pending' check (status in ('pending','approved','done','cancelled')),
  period_id uuid references public.periods(id),
  refunded boolean not null default false, created_at timestamptz not null default now()
);

create table public.achievements_unlocked (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id), achievement_id text not null,
  unlocked_at timestamptz not null default now(), unique (user_id, achievement_id)
);
create table public.rest_days (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id), period_id uuid not null references public.periods(id),
  date date, status text not null default 'pending' check (status in ('pending','scheduled','used'))
);
create table public.spins (
  id uuid primary key default gen_random_uuid(), mode text not null, options text[] not null,
  result text not null, result_id text, by_user uuid references public.profiles(id), created_at timestamptz not null default now()
);
create table public.audit_log (
  id bigint generated always as identity primary key,
  actor_id uuid, action text not null, entity_type text, entity_id text, reason text not null default '',
  created_at timestamptz not null default now()
);

-- ======================= 2. DADOS INICIAIS ============================
insert into public.categories values ('cozinha','Cozinha','🍳'),('banheiro','Banheiro','🚿'),('quarto','Quarto','🛏️'),
 ('sala','Sala','🛋️'),('lavanderia','Lavanderia','🧺'),('organizacao','Organização','🗂️'),('limpeza','Limpeza geral','🧽'),
 ('animais','Cuidados com animais','🐈'),('outras','Outras tarefas','✨');
insert into public.catalog (id,title,points,category_id,freq) values
 ('m0','Arrumar a cama',5,'quarto','daily'),
 ('m1','Lavar a louça',10,'cozinha','daily'),
 ('m2','Limpar a bancada e o fogão',5,'cozinha','daily'),
 ('m3','Tirar o lixo',5,'cozinha','daily'),
 ('m4','Varrer a cozinha',8,'cozinha','daily'),
 ('m5','Dar comida e água aos pets',5,'animais','daily'),
 ('m6','Limpar a caixa de areia dos gatos',8,'animais','daily'),
 ('m7','Recolher o que está fora do lugar',5,'sala','daily'),
 ('m8','Varrer e passar pano na casa',20,'limpeza','weekly'),
 ('m9','Passar aspirador',15,'limpeza','weekly'),
 ('m10','Limpar o banheiro',25,'banheiro','weekly'),
 ('m11','Trocar a roupa de cama',15,'quarto','weekly'),
 ('m12','Lavar roupas',15,'lavanderia','weekly'),
 ('m13','Estender ou recolher roupas',10,'lavanderia','weekly'),
 ('m14','Dobrar e guardar roupas',10,'lavanderia','weekly'),
 ('m15','Passar roupas',15,'lavanderia','weekly'),
 ('m16','Organizar a sala',10,'sala','weekly'),
 ('m17','Limpar espelhos e vidros',10,'limpeza','weekly'),
 ('m18','Regar as plantas',10,'outras','weekly'),
 ('m19','Levar o lixo reciclável',10,'outras','weekly'),
 ('m20','Fazer as compras da casa',25,'outras','weekly'),
 ('m21','Limpar o box e o rejunte',35,'banheiro','biweekly'),
 ('m22','Limpar forno e micro-ondas',30,'cozinha','biweekly'),
 ('m23','Lavar as lixeiras',25,'limpeza','biweekly'),
 ('m24','Lavar toalhas e panos de prato',25,'lavanderia','biweekly'),
 ('m25','Organizar a despensa',30,'organizacao','biweekly'),
 ('m26','Limpar as janelas',35,'limpeza','biweekly'),
 ('m27','Banho nos pets',40,'animais','biweekly'),
 ('m28','Limpar atrás e embaixo dos móveis',45,'sala','biweekly'),
 ('m29','Limpar a geladeira',60,'cozinha','monthly'),
 ('m30','Limpeza geral da casa',100,'limpeza','monthly'),
 ('m31','Organizar um armário',50,'organizacao','monthly'),
 ('m32','Lavar cortinas e tapetes',80,'lavanderia','monthly'),
 ('m33','Lavar cobertores e edredom',70,'lavanderia','monthly'),
 ('m34','Limpar o ar-condicionado ou ventilador',50,'limpeza','monthly'),
 ('m35','Faxina da varanda ou quintal',70,'outras','monthly'),
 ('m36','Limpar ralos e filtros',50,'limpeza','monthly'),
 ('m37','Descongelar e limpar o freezer',60,'cozinha','monthly'),
 ('m38','Limpar o armário da cozinha por dentro',55,'cozinha','monthly');
insert into public.rewards (name,description,cost,kind,payload,per_user_limit) values
 ('Escolher o filme da noite','Você escolhe o filme.',30,'normal','{}',0),
 ('Escolher o jantar','Você escolhe o que será o jantar.',40,'normal','{}',0),
 ('Uma hora livre de uma tarefa','Combine com o grupo qual tarefa.',60,'normal','{}',0),
 ('Escolher a próxima playlist','A casa ouve a sua playlist.',15,'normal','{}',0),
 ('Favor doméstico acordado','Um pequeno favor combinado de antemão.',70,'normal','{}',0),
 ('Avatar especial 🦁','Libera o avatar 🦁 para você.',100,'avatar','{"emoji":"🦁"}',1),
 ('Título Mestre do Rodo','Mostra o título ao lado do seu nome.',80,'title','{"title":"Mestre do Rodo"}',1);
-- primeiro período: de hoje até o fim do mês
insert into public.periods (start_date,end_date)
  values (public.today_br(), (date_trunc('month', public.today_br()) + interval '1 month - 1 day')::date);

-- ======================= 3. FUNÇÕES AUXILIARES =======================
create or replace function public.is_member() returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles where id = auth.uid() and active) $$;
create or replace function public.is_admin() returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles where id = auth.uid() and active and role = 'admin') $$;

create or replace function public.aud(p_action text, p_entity text, p_id text, p_reason text default '') returns void
language sql security definer set search_path = public as $$
  insert into audit_log (actor_id, action, entity_type, entity_id, reason) values (auth.uid(), p_action, p_entity, p_id, coalesce(p_reason,''))
$$;
create or replace function public.need_admin() returns void language plpgsql stable security definer set search_path = public as $$
begin if not is_admin() then raise exception 'Você não tem permissão para esta ação.'; end if; end $$;
create or replace function public.need_member() returns void language plpgsql stable security definer set search_path = public as $$
begin if not is_member() then raise exception 'Você não tem permissão para esta ação.'; end if; end $$;
create or replace function public.log_item(p_text text) returns jsonb language sql stable as $$
  select jsonb_build_array(jsonb_build_object('at', now(), 'by', auth.uid(), 'text', p_text)) $$;

create or replace function public.add_month(d date, anchor int) returns date language sql immutable as $$
  select (date_trunc('month', d) + interval '1 month')::date
         + (least(anchor, extract(day from (date_trunc('month', d) + interval '2 month - 1 day'))::int) - 1) $$;
create or replace function public.adv_date(freq text, d date, anchor int, itv int) returns date language sql immutable as $$
  select case freq when 'daily' then d + 1 when 'weekly' then d + 7 when 'monthly' then public.add_month(d, anchor)
                   else d + coalesce(itv, 1) end $$;

create or replace function public.player_ok(u uuid) returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles where id = u and active and plays) $$;

create or replace function public.score_of(u uuid, per uuid) returns int language sql stable security definer set search_path = public as $$
  select coalesce(sum(points), 0)::int from score_tx where user_id = u and period_id = per $$;
create or replace function public.balance_of(u uuid) returns int language sql stable security definer set search_path = public as $$
  select coalesce(sum(amount), 0)::int from wallet_tx where user_id = u $$;

-- ======================= 4. CADASTRO (gatilho do Auth) ===============
-- As regras ficam em um só lugar: a tela consulta signup_problem() para mostrar o motivo e o gatilho a impõe.
create or replace function public.signup_problem(p_name text, p_code text, p_email text) returns text
language plpgsql stable security definer set search_path = public as $$
declare nm text := btrim(coalesce(p_name, '')); adm boolean;
begin
  adm := exists (select 1 from admin_emails where email = lower(btrim(coalesce(p_email, '')))) and not exists (select 1 from profiles where role = 'admin');
  if not adm then
    if not (select open_signup from settings where id = 1) then return 'Os cadastros estão fechados pelo administrador.'; end if;
    if upper(btrim(coalesce(p_code, ''))) <> (select house_code from app_secrets where id = 1) then return 'Código da casa incorreto.'; end if;
    if (select count(*) from profiles where active and plays) >= 4 then return 'O jogo já tem 4 jogadores.'; end if;
    if char_length(nm) not between 2 and 20 then return 'O nome deve ter de 2 a 20 caracteres.'; end if;
  end if;
  if exists (select 1 from profiles where active and lower(name) = lower(nm)) then return 'Já existe alguém com esse nome.'; end if;
  return null;
end $$;

-- Ao criar a conta no Supabase Auth, cria o perfil. O e-mail de admin_emails vira o administrador (só se ainda não existir um).
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path = public as $$
declare nm text; adm boolean; av text; co text; problem text;
begin
  perform pg_advisory_xact_lock(7002);
  adm := exists (select 1 from admin_emails where email = lower(new.email)) and not exists (select 1 from profiles where role = 'admin');
  nm := btrim(coalesce(new.raw_user_meta_data->>'name', ''));
  if adm and char_length(nm) not between 2 and 20 then nm := 'Administrador'; end if;
  problem := signup_problem(nm, new.raw_user_meta_data->>'house_code', new.email);
  if problem is not null then raise exception '%', problem; end if;
  av := coalesce(nullif(btrim(new.raw_user_meta_data->>'avatar'), ''), case when adm then '🛡️' else '🦊' end);
  if char_length(av) > 12 or exists (select 1 from rewards where kind = 'avatar' and payload->>'emoji' = av) then av := '🦊'; end if;
  co := coalesce(new.raw_user_meta_data->>'color', '#2B63E8');
  if co !~ '^#[0-9A-Fa-f]{6}$' then co := '#2B63E8'; end if;
  insert into profiles (id, name, avatar, color, role, plays) values (new.id, nm, av, co, case when adm then 'admin' else 'user' end, not adm);
  insert into audit_log (actor_id, action, entity_type, entity_id, reason) values (new.id, 'signup', 'user', new.id::text, nm);
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

-- Consulta liberada a quem ainda não entrou (tela de cadastro)
create or replace function public.public_status() returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('appName', s.app_name, 'openSignup', s.open_signup,
    'players', (select count(*) from profiles where active and plays),
    'hasAdmin', exists (select 1 from profiles where role = 'admin')) from settings s where s.id = 1 $$;

-- Só o administrador enxerga o código da casa
create or replace function public.get_house_code() returns text language plpgsql stable security definer set search_path = public as $$
begin perform need_admin(); return (select house_code from app_secrets where id = 1); end $$;

-- ======================= 5. LEITURA (RLS) ============================
do $$ declare t text; begin
  foreach t in array array['settings','profiles','categories','catalog','periods','tasks','occurrences','evidence','score_tx',
    'wallet_tx','rewards','redemptions','achievements_unlocked','rest_days','spins'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('create policy "membros leem" on public.%I for select to authenticated using (public.is_member())', t);
  end loop;
end $$;
alter table public.admin_emails enable row level security;           -- sem política: ninguém lê pelo app
alter table public.app_secrets enable row level security;            -- idem
alter table public.audit_log enable row level security;
create policy "admin le auditoria" on public.audit_log for select to authenticated using (public.is_admin());
-- Não há política de INSERT/UPDATE/DELETE: o app só escreve pelas funções abaixo.

-- ======================= 6. CONQUISTAS ===============================
create or replace function public.check_achievements(u uuid) returns text[]
language plpgsql security definer set search_path = public as $$
declare n int; dd int; kit int; ban int; late int; wk int; wins int; cb boolean; got text[] := '{}'; a record; ins int;
begin
  select count(*), count(distinct day) into n, dd from score_tx where user_id = u and type = 'task' and reversed_by is null;
  select count(*) into kit from score_tx s join occurrences o on o.id = s.occurrence_id where s.user_id = u and s.type = 'task' and s.reversed_by is null and o.category_id = 'cozinha';
  select count(*) into ban from score_tx s join occurrences o on o.id = s.occurrence_id where s.user_id = u and s.type = 'task' and s.reversed_by is null and o.category_id = 'banheiro';
  select count(*) into late from occurrences where assigned_to = u and status in ('available','in_progress') and due_date < today_br();
  select coalesce(max(c), 0) into wk from (select count(*) over (order by day range between current row and interval '6 days' following) c
      from score_tx where user_id = u and type = 'task' and reversed_by is null) x;
  select count(*) into wins from periods where status = 'closed' and winner_id = u;
  select exists (select 1 from (select day - lag(day) over (order by day) g from (select distinct day from score_tx where user_id = u and type = 'task' and reversed_by is null) d) z where g >= 7) into cb;
  for a in select * from (values
      ('first', 5, n >= 1), ('ten', 10, n >= 10), ('days3', 5, dd >= 3), ('kitchen', 10, kit >= 10), ('bath', 10, ban >= 5),
      ('clean', 5, n >= 1 and late = 0), ('week', 10, wk >= 5), ('champ', 20, wins >= 1), ('back', 5, cb)) v(id, coins, ok) where ok loop
    insert into achievements_unlocked (user_id, achievement_id) values (u, a.id) on conflict do nothing;
    get diagnostics ins = row_count;
    if ins > 0 then
      if a.coins > 0 then insert into wallet_tx (user_id, type, amount, ref, reason) values (u, 'bonus', a.coins, a.id, 'Conquista: ' || a.id); end if;
      insert into audit_log (actor_id, action, entity_type, entity_id, reason) values (null, 'achievement', 'user', u::text, a.id);
      got := got || a.id::text;
    end if;
  end loop;
  return got;
end $$;

-- ======================= 7. RECORRÊNCIA E PENALIDADES ================
create or replace function public.gen_occurrences() returns int language plpgsql security definer set search_path = public as $$
declare d tasks; per uuid; td date := today_br(); due date; lst date; g int; n int := 0;
begin
  select id into per from periods where status = 'open'; if per is null then return 0; end if;
  for d in select * from tasks where active and frequency <> 'once' and next_due is not null and next_due <= td for update loop
    due := d.next_due; lst := null; g := 0;
    while due <= td and g < 800 loop lst := due; due := adv_date(d.frequency, due, d.anchor_day, d.interval_days); g := g + 1; end loop;
    if lst is not null then
      insert into occurrences (task_id, period_id, title, description, category_id, points, assigned_to, due_date, recurring, log)
        values (d.id, per, d.title, d.description, d.category_id, d.points, d.assigned_to, lst, true, jsonb_build_array(jsonb_build_object('at', now(), 'by', 'system', 'text', 'Criada')))
        on conflict (task_id, due_date) do nothing;
      if found then n := n + 1; end if;
    end if;
    update tasks set next_due = due where id = d.id;
  end loop;
  return n;
end $$;

-- Pode ser chamada por qualquer jogador logado (o app chama ao abrir) e também agendada. É idempotente.
create or replace function public.sweep() returns void language plpgsql security definer set search_path = public as $$
declare per periods; cfg jsonb; td date := today_br(); o occurrences; amt int; already int; room int; cur int; lp int; mp int; mx int; gr int;
begin
  perform need_member();
  perform pg_advisory_xact_lock(7001);
  select * into per from periods where status = 'open'; if not found then return; end if;
  perform gen_occurrences();
  select penalty into cfg from settings where id = 1;
  if coalesce((cfg->>'enabled')::boolean, false) then
    lp := coalesce((cfg->>'latePoints')::int, 0); mp := coalesce((cfg->>'missPoints')::int, 0);
    mx := coalesce((cfg->>'maxPerOcc')::int, 0); gr := coalesce((cfg->>'grace')::int, 0);
    for o in select * from occurrences where period_id = per.id and assigned_to is not null and due_date < td
             and status in ('available','in_progress','rejected') for update loop
      if not o.late_pen and lp > 0 then
        select coalesce(-sum(points), 0) into already from score_tx where occurrence_id = o.id and type = 'penalty' and reversed_by is null;
        room := greatest(0, mx - already); cur := score_of(o.assigned_to, per.id); amt := least(lp, room, greatest(0, cur));
        update occurrences set late_pen = true where id = o.id;
        if amt > 0 then insert into score_tx (user_id, occurrence_id, period_id, type, points, reason, created_by) values (o.assigned_to, o.id, per.id, 'penalty', -amt, 'Atraso: ' || o.title, null); end if;
      end if;
      if not o.miss_pen and mp > 0 and td > o.due_date + gr then
        select coalesce(-sum(points), 0) into already from score_tx where occurrence_id = o.id and type = 'penalty' and reversed_by is null;
        room := greatest(0, mx - already); cur := score_of(o.assigned_to, per.id); amt := least(mp, room, greatest(0, cur));
        update occurrences set miss_pen = true where id = o.id;
        if amt > 0 then insert into score_tx (user_id, occurrence_id, period_id, type, points, reason, created_by) values (o.assigned_to, o.id, per.id, 'penalty', -amt, 'Não executada no prazo: ' || o.title, null); end if;
      end if;
    end loop;
  end if;
end $$;

-- ======================= 8. TAREFAS ==================================
create or replace function public.check_task_payload(p jsonb, is_new boolean) returns void language plpgsql stable security definer set search_path = public as $$
declare t text := btrim(coalesce(p->>'title','')); pts int; fr text := p->>'frequency'; due date; itv int;
begin
  if char_length(t) not between 2 and 80 then raise exception 'Informe um nome com 2 a 80 caracteres.'; end if;
  pts := case when coalesce(p->>'points','') ~ '^[0-9]+$' then (p->>'points')::int end;
  if pts is null or pts not between 1 and 500 then raise exception 'A pontuação deve ser um número inteiro de 1 a 500.'; end if;
  if not exists (select 1 from categories where id = p->>'categoryId') then raise exception 'Categoria inválida.'; end if;
  if fr is null or fr not in ('once','daily','weekly','monthly','custom') then raise exception 'Frequência inválida.'; end if;
  if fr = 'custom' then
    itv := case when coalesce(p->>'interval','') ~ '^[0-9]+$' then (p->>'interval')::int end;
    if itv is null or itv not between 2 and 365 then raise exception 'Informe o intervalo em dias (2 a 365).'; end if;
  end if;
  begin due := (p->>'dueDate')::date; exception when others then due := null; end;
  if due is null then raise exception 'Informe um prazo válido.'; end if;
  if is_new and due < today_br() then raise exception 'O prazo não pode estar no passado.'; end if;
  if nullif(p->>'assignedTo','') is not null and not player_ok((p->>'assignedTo')::uuid) then raise exception 'Responsável inexistente ou inativo.'; end if;
end $$;

create or replace function public.create_task(p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare tid uuid; per uuid; due date; fr text; t text; asg uuid;
begin
  perform need_admin(); perform check_task_payload(p, true);
  t := btrim(p->>'title'); due := (p->>'dueDate')::date; fr := p->>'frequency'; asg := nullif(p->>'assignedTo','')::uuid;
  select id into per from periods where status = 'open'; if per is null then raise exception 'Nenhum período aberto.'; end if;
  if exists (select 1 from occurrences where lower(btrim(title)) = lower(t) and due_date = due and status <> 'cancelled') then
    raise exception 'Já existe uma tarefa com esse nome e esse prazo.'; end if;
  insert into tasks (title, description, category_id, frequency, interval_days, points, assigned_to, next_due, anchor_day, active, log)
    values (t, left(btrim(coalesce(p->>'desc','')), 300), p->>'categoryId', fr, case when fr = 'custom' then (p->>'interval')::int end,
            (p->>'points')::int, asg, due, extract(day from due)::int, true, log_item('Criada')) returning id into tid;
  if fr = 'once' then
    insert into occurrences (task_id, period_id, title, description, category_id, points, assigned_to, due_date, recurring, log)
      select id, per, title, description, category_id, points, assigned_to, due, false, log_item('Criada') from tasks where id = tid;
    update tasks set next_due = null, active = false where id = tid;
  else perform gen_occurrences(); end if;
  perform aud('create', 'task', tid::text, t);
  return jsonb_build_object('ok', true, 'id', tid);
end $$;

create or replace function public.update_task_def(p_id uuid, p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare d tasks;
begin
  perform need_admin(); select * into d from tasks where id = p_id for update; if not found then raise exception 'Tarefa não encontrada.'; end if;
  perform check_task_payload(p, false);
  update tasks set title = btrim(p->>'title'), description = left(btrim(coalesce(p->>'desc','')), 300), category_id = p->>'categoryId',
    points = (p->>'points')::int, assigned_to = nullif(p->>'assignedTo','')::uuid, frequency = p->>'frequency',
    interval_days = case when p->>'frequency' = 'custom' then (p->>'interval')::int end,
    active = coalesce((p->>'active')::boolean, active),
    next_due = case when frequency <> 'once' then (p->>'dueDate')::date else next_due end,
    updated_at = now(), log = log || log_item('Editada') where id = p_id;
  perform aud('update', 'task', p_id::text, '');
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.delete_task_def(p_id uuid) returns jsonb language plpgsql security definer set search_path = public as $$
begin
  perform need_admin(); if not exists (select 1 from tasks where id = p_id) then raise exception 'Tarefa não encontrada.'; end if;
  if exists (select 1 from occurrences where task_id = p_id) then
    update tasks set active = false where id = p_id; perform aud('deactivate', 'task', p_id::text, '');
    return jsonb_build_object('ok', true, 'deactivated', true);
  end if;
  delete from tasks where id = p_id; perform aud('delete', 'task', p_id::text, '');
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.update_occurrence(p_id uuid, p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare o occurrences; pts int; due date; asg uuid; ch text[] := '{}';
begin
  perform need_admin(); select * into o from occurrences where id = p_id for update; if not found then raise exception 'Tarefa não encontrada.'; end if;
  if o.status not in ('available','in_progress','rejected') then raise exception 'Só é possível editar tarefas ainda não enviadas.'; end if;
  pts := case when coalesce(p->>'points','') ~ '^[0-9]+$' then (p->>'points')::int end;
  if pts is null or pts not between 1 and 500 then raise exception 'A pontuação deve ser um número inteiro de 1 a 500.'; end if;
  begin due := (p->>'dueDate')::date; exception when others then due := null; end;
  if due is null then raise exception 'Informe um prazo válido.'; end if;
  asg := nullif(p->>'assignedTo','')::uuid;
  if asg is not null and not player_ok(asg) then raise exception 'Responsável inexistente ou inativo.'; end if;
  if o.points <> pts then ch := ch || ('pontos ' || o.points || '→' || pts); end if;
  if o.due_date <> due then ch := ch || ('prazo ' || o.due_date || '→' || due); end if;
  if o.assigned_to is distinct from asg then ch := ch || 'responsável alterado'::text; end if;
  update occurrences set points = pts, due_date = due, assigned_to = asg, description = coalesce(left(p->>'desc', 300), description),
    log = case when array_length(ch,1) > 0 then log || log_item('Editada: ' || array_to_string(ch, ', ')) else log end where id = p_id;
  if array_length(ch,1) > 0 then perform aud('update', 'occurrence', p_id::text, array_to_string(ch, ', ')); end if;
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.cancel_occurrence(p_id uuid, p_reason text default '') returns jsonb language plpgsql security definer set search_path = public as $$
declare o occurrences;
begin
  perform need_admin(); select * into o from occurrences where id = p_id for update; if not found then raise exception 'Tarefa não encontrada.'; end if;
  if o.status not in ('available','in_progress','rejected','awaiting_approval') then raise exception 'Esta tarefa não pode ser cancelada.'; end if;
  update occurrences set status = 'cancelled', log = log || log_item('Cancelada' || case when coalesce(p_reason,'') <> '' then ': ' || p_reason else '' end) where id = p_id;
  perform aud('cancel', 'occurrence', p_id::text, p_reason); return jsonb_build_object('ok', true);
end $$;

create or replace function public.claim_occurrence(p_id uuid) returns jsonb language plpgsql security definer set search_path = public as $$
declare o occurrences; nm text;
begin
  if not player_ok(auth.uid()) then raise exception 'Apenas jogadores podem assumir tarefas.'; end if;
  select * into o from occurrences where id = p_id for update; if not found then raise exception 'Tarefa não encontrada.'; end if;
  if o.assigned_to is not null then raise exception 'Esta tarefa já tem responsável.'; end if;
  if o.status not in ('available','in_progress','rejected') then raise exception 'Esta tarefa não está disponível.'; end if;
  select name into nm from profiles where id = auth.uid();
  update occurrences set assigned_to = auth.uid(), log = log || log_item('Assumida por ' || nm) where id = p_id;
  perform aud('claim', 'occurrence', p_id::text, ''); return jsonb_build_object('ok', true);
end $$;

create or replace function public.assign_occurrence(p_id uuid, p_to uuid) returns jsonb language plpgsql security definer set search_path = public as $$
declare o occurrences; nm text;
begin
  perform need_admin(); select * into o from occurrences where id = p_id for update; if not found then raise exception 'Tarefa não encontrada.'; end if;
  if not player_ok(p_to) then raise exception 'Participante inexistente ou inativo.'; end if;
  if o.status not in ('available','in_progress','rejected') then raise exception 'Esta tarefa não pode ser reatribuída agora.'; end if;
  select name into nm from profiles where id = p_to;
  update occurrences set assigned_to = p_to, log = log || log_item('Atribuída a ' || nm) where id = p_id;
  perform aud('assign', 'occurrence', p_id::text, nm); return jsonb_build_object('ok', true);
end $$;

create or replace function public.start_occurrence(p_id uuid) returns jsonb language plpgsql security definer set search_path = public as $$
declare o occurrences;
begin
  select * into o from occurrences where id = p_id for update;
  if not found or o.assigned_to is distinct from auth.uid() or not is_member() then raise exception 'Você não tem permissão para esta ação.'; end if;
  if o.status <> 'available' then raise exception 'Esta tarefa já foi iniciada.'; end if;
  update occurrences set status = 'in_progress', log = log || log_item('Iniciada') where id = p_id;
  return jsonb_build_object('ok', true);
end $$;

-- ======================= 9. COMPROVAÇÃO E APROVAÇÃO ==================
create or replace function public.submit_evidence(p_occ uuid, p_path text) returns jsonb language plpgsql security definer set search_path = public as $$
declare o occurrences;
begin
  perform need_member();
  select * into o from occurrences where id = p_occ for update; if not found then raise exception 'Tarefa não encontrada.'; end if;
  if o.assigned_to is distinct from auth.uid() then raise exception 'Só o responsável pode enviar a comprovação.'; end if;
  if o.status not in ('available','in_progress','rejected') then raise exception 'Esta tarefa não aceita novo envio agora.'; end if;
  if not exists (select 1 from periods where id = o.period_id and status = 'open') then raise exception 'O período desta tarefa foi encerrado.'; end if;
  if coalesce(p_path,'') = '' or split_part(p_path, '/', 1) <> auth.uid()::text then raise exception 'Foto inválida.'; end if;
  insert into evidence (occurrence_id, submitted_by, image_path) values (p_occ, auth.uid(), p_path);
  update occurrences set status = 'awaiting_approval', submitted_by = auth.uid(), submitted_at = now(), photo_path = p_path,
    rejection_reason = '', log = log || log_item('Comprovação enviada') where id = p_occ;
  perform aud('submit', 'occurrence', p_occ::text, ''); return jsonb_build_object('ok', true);
end $$;

create or replace function public.review_occurrence(p_occ uuid, p_approve boolean, p_reason text default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare o occurrences; ev evidence; rate int; coins int; ach text[]; r text := btrim(coalesce(p_reason, ''));
begin
  perform need_member();
  select * into o from occurrences where id = p_occ for update; if not found then raise exception 'Tarefa não encontrada.'; end if;
  if o.status <> 'awaiting_approval' then raise exception 'Esta tarefa não está aguardando aprovação.'; end if;
  if o.submitted_by = auth.uid() or o.assigned_to = auth.uid() then raise exception 'Você não pode aprovar a sua própria tarefa.'; end if;
  select * into ev from evidence where occurrence_id = p_occ and review_status = 'pending' order by submitted_at desc limit 1;
  if not p_approve then
    if char_length(r) < 3 then raise exception 'Informe o motivo da rejeição.'; end if;
    update occurrences set status = 'rejected', rejection_reason = r, reviewed_by = auth.uid(), reviewed_at = now(), log = log || log_item('Rejeitada: ' || r) where id = p_occ;
    update evidence set review_status = 'rejected', reviewed_by = auth.uid(), reviewed_at = now(), rejection_reason = r where id = ev.id;
    perform aud('reject', 'occurrence', p_occ::text, r); return jsonb_build_object('ok', true);
  end if;
  if not exists (select 1 from periods where id = o.period_id and status = 'open') then raise exception 'O período desta tarefa foi encerrado.'; end if;
  if o.assigned_to is null then raise exception 'Tarefa sem responsável não gera pontos.'; end if;
  if exists (select 1 from score_tx where occurrence_id = p_occ and type = 'task') then raise exception 'Os pontos desta tarefa já foram creditados.'; end if;
  update occurrences set status = 'done', completed_at = now(), reviewed_by = auth.uid(), reviewed_at = now(), log = log || log_item('Aprovada, +' || o.points || ' pontos') where id = p_occ;
  update evidence set review_status = 'approved', reviewed_by = auth.uid(), reviewed_at = now() where id = ev.id;
  insert into score_tx (user_id, occurrence_id, period_id, type, points, reason, created_by) values (o.assigned_to, p_occ, o.period_id, 'task', o.points, o.title, auth.uid());
  select coin_rate into rate from settings where id = 1; coins := o.points * coalesce(rate, 0);
  if coins > 0 then insert into wallet_tx (user_id, type, amount, ref, reason) values (o.assigned_to, 'earn', coins, p_occ::text, 'Tarefa: ' || o.title); end if;
  ach := check_achievements(o.assigned_to);
  perform aud('approve', 'occurrence', p_occ::text, '');
  return jsonb_build_object('ok', true, 'points', o.points, 'achievements', to_jsonb(ach), 'userId', o.assigned_to);
end $$;

-- ======================= 10. AJUSTES, ESTORNOS, CONTESTAÇÃO ==========
create or replace function public.adjust_points(p_user uuid, p_delta int, p_reason text, p_period uuid default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare per periods; r text := btrim(coalesce(p_reason, ''));
begin
  perform need_admin();
  if not exists (select 1 from profiles where id = p_user) then raise exception 'Participante inexistente.'; end if;
  if p_delta is null or p_delta = 0 or abs(p_delta) > 500 then raise exception 'Informe um ajuste inteiro diferente de zero (até 500).'; end if;
  if char_length(r) < 3 then raise exception 'A justificativa é obrigatória.'; end if;
  select * into per from periods where id = coalesce(p_period, (select id from periods where status = 'open')); if not found then raise exception 'Período inexistente.'; end if;
  insert into score_tx (user_id, period_id, type, points, reason, post_close, created_by) values (p_user, per.id, 'adjust', p_delta, r, per.status = 'closed', auth.uid());
  perform aud(case when per.status = 'closed' then 'adjust_closed' else 'adjust' end, 'user', p_user::text, r);
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.do_reverse(p_tx uuid, p_reason text) returns void language plpgsql security definer set search_path = public as $$
declare t score_tx; per periods; rid uuid; earned int; back int;
begin
  select * into t from score_tx where id = p_tx for update; if not found then raise exception 'Registro não encontrado.'; end if;
  if t.type = 'reversal' or t.reversed_by is not null then raise exception 'Este registro já foi estornado ou é um estorno.'; end if;
  select * into per from periods where id = t.period_id;
  insert into score_tx (user_id, occurrence_id, period_id, type, points, reason, ref_tx, post_close, created_by)
    values (t.user_id, t.occurrence_id, t.period_id, 'reversal', -t.points, p_reason, t.id, per.status = 'closed', auth.uid()) returning id into rid;
  update score_tx set reversed_by = rid where id = p_tx;
  if t.type = 'task' then
    select coalesce(sum(amount), 0) into earned from wallet_tx where type = 'earn' and ref = t.occurrence_id::text and user_id = t.user_id;
    back := least(earned, greatest(0, balance_of(t.user_id)));
    if back > 0 then insert into wallet_tx (user_id, type, amount, ref, reason) values (t.user_id, 'reversal', -back, t.occurrence_id::text, 'Estorno: ' || p_reason); end if;
    update occurrences set log = log || log_item('Pontos estornados: ' || p_reason) where id = t.occurrence_id;
  end if;
  perform aud(case when per.status = 'closed' then 'reverse_closed' else 'reverse' end, 'scoreTx', p_tx::text, p_reason);
end $$;

create or replace function public.reverse_score(p_tx uuid, p_reason text) returns jsonb language plpgsql security definer set search_path = public as $$
begin
  perform need_admin();
  if char_length(btrim(coalesce(p_reason, ''))) < 3 then raise exception 'A justificativa é obrigatória.'; end if;
  perform do_reverse(p_tx, btrim(p_reason)); return jsonb_build_object('ok', true);
end $$;

create or replace function public.contest_penalty(p_tx uuid, p_text text) returns jsonb language plpgsql security definer set search_path = public as $$
declare t score_tx;
begin
  perform need_member(); select * into t from score_tx where id = p_tx for update;
  if not found or t.type <> 'penalty' or t.user_id <> auth.uid() then raise exception 'Você não tem permissão para esta ação.'; end if;
  if t.contest is not null then raise exception 'Esta penalidade já foi contestada.'; end if;
  if char_length(btrim(coalesce(p_text, ''))) < 3 then raise exception 'Explique o motivo da contestação.'; end if;
  update score_tx set contest = jsonb_build_object('text', btrim(p_text), 'at', now(), 'status', 'open') where id = p_tx;
  perform aud('contest', 'scoreTx', p_tx::text, p_text); return jsonb_build_object('ok', true);
end $$;

create or replace function public.resolve_contest(p_tx uuid, p_accept boolean, p_reason text) returns jsonb language plpgsql security definer set search_path = public as $$
declare t score_tx; r text := btrim(coalesce(p_reason, ''));
begin
  perform need_admin(); select * into t from score_tx where id = p_tx for update;
  if not found or t.contest is null or t.contest->>'status' <> 'open' then raise exception 'Contestação não encontrada.'; end if;
  if char_length(r) < 3 then raise exception 'Informe a justificativa da decisão.'; end if;
  if p_accept then perform do_reverse(p_tx, 'Contestação aceita: ' || r); end if;
  update score_tx set contest = contest || jsonb_build_object('status', case when p_accept then 'accepted' else 'denied' end, 'reply', r, 'by', auth.uid()) where id = p_tx;
  perform aud('resolve_contest', 'scoreTx', p_tx::text, r); return jsonb_build_object('ok', true);
end $$;

-- ======================= 11. ENCERRAMENTO DO PERÍODO =================
create or replace function public.close_period(p_winner uuid default null, p_tie_note text default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare per periods; np periods; top int; tied uuid[]; win uuid; tie jsonb; td date := today_br(); fin jsonb; ns date; n int; note text := btrim(coalesce(p_tie_note, ''));
begin
  perform need_admin(); perform pg_advisory_xact_lock(7001);
  select * into per from periods where status = 'open' for update; if not found then raise exception 'Nenhum período aberto.'; end if;
  if exists (select 1 from occurrences where period_id = per.id and status = 'awaiting_approval') then
    raise exception 'Resolva as aprovações pendentes antes de encerrar o período.'; end if;
  create temp table if not exists _st (uid uuid, pts int, tasks int, rec int, pos int) on commit drop; truncate _st;
  insert into _st select u.id, score_of(u.id, per.id),
      (select count(*) from score_tx s where s.user_id = u.id and s.period_id = per.id and s.type = 'task' and s.reversed_by is null),
      coalesce((select sum(s.points) from score_tx s join occurrences o on o.id = s.occurrence_id where s.user_id = u.id and s.period_id = per.id and s.type = 'task' and s.reversed_by is null and o.recurring), 0), 0
    from (select id from profiles where active and plays union select user_id from score_tx where period_id = per.id) u;
  update _st set pos = r.pos from (select uid, rank() over (order by pts desc, tasks desc, rec desc) pos from _st) r where r.uid = _st.uid;
  select pts into top from _st where pos = 1 limit 1;
  if top is not null and top > 0 then
    select array_agg(uid) into tied from _st where pos = 1;
    if array_length(tied, 1) > 1 then
      if p_winner is not null and p_winner = any (tied) then
        if char_length(note) < 3 then raise exception 'Registre como o empate foi decidido.'; end if;
        win := p_winner; tie := jsonb_build_object('users', to_jsonb(tied), 'note', note, 'by', auth.uid());
      else return jsonb_build_object('ok', true, 'tie', to_jsonb(tied)); end if;
    else win := tied[1]; end if;
  end if;
  select coalesce(jsonb_agg(jsonb_build_object('userId', uid, 'pts', pts, 'tasks', tasks, 'pos', pos) order by pos, uid), '[]') into fin from _st;
  update periods set status = 'closed', end_date = least(end_date, td), winner_id = win,
    prize_amount = case when win is not null then (select prize from settings where id = 1) else 0 end, prize_paid = false,
    tie_resolution = tie, final = fin, closed_at = now(), closed_by = auth.uid() where id = per.id;
  if win is not null then
    insert into rest_days (user_id, period_id) select win, per.id from generate_series(1, (select rest_days from settings where id = 1));
  end if;
  ns := least(end_date, td) + 1 from periods where id = per.id;
  insert into periods (start_date, end_date) values (ns, (date_trunc('month', ns) + interval '1 month - 1 day')::date) returning * into np;
  update occurrences set period_id = np.id, log = log || jsonb_build_array(jsonb_build_object('at', now(), 'by', 'system', 'text', 'Transferida para o novo período'))
    where period_id = per.id and status in ('available','in_progress','rejected');
  perform aud('close_period', 'period', per.id::text, case when win is not null then 'Vencedor: ' || (select name from profiles where id = win) else 'Sem vencedor' end);
  if win is not null then perform check_achievements(win); end if;
  perform gen_occurrences();
  return jsonb_build_object('ok', true, 'winner', win, 'periodId', per.id);
end $$;

create or replace function public.set_rest_day(p_id uuid, p_date date, p_status text) returns jsonb language plpgsql security definer set search_path = public as $$
begin
  perform need_admin(); if p_status not in ('pending','scheduled','used') then raise exception 'Status inválido.'; end if;
  if p_status <> 'pending' and p_date is null then raise exception 'Informe a data do descanso.'; end if;
  update rest_days set date = case when p_status = 'pending' then null else p_date end, status = p_status where id = p_id;
  if not found then raise exception 'Registro não encontrado.'; end if;
  perform aud('rest', 'restDay', p_id::text, p_status); return jsonb_build_object('ok', true);
end $$;

create or replace function public.set_prize_paid(p_period uuid, p_paid boolean) returns jsonb language plpgsql security definer set search_path = public as $$
begin
  perform need_admin(); update periods set prize_paid = coalesce(p_paid, false) where id = p_period and status = 'closed';
  if not found then raise exception 'Período inválido.'; end if;
  perform aud('prize', 'period', p_period::text, case when p_paid then 'pago' else 'pendente' end); return jsonb_build_object('ok', true);
end $$;

-- ======================= 12. LOJA ====================================
create or replace function public.redeem_reward(p_reward uuid, p_key uuid) returns jsonb language plpgsql security definer set search_path = public as $$
declare r rewards; me profiles; per uuid; rid uuid; n int;
begin
  if not player_ok(auth.uid()) then raise exception 'Apenas jogadores podem resgatar recompensas.'; end if;
  if not (select shop_enabled from settings where id = 1) then raise exception 'A loja está desativada.'; end if;
  if exists (select 1 from redemptions where request_key = p_key) then raise exception 'Este resgate já foi processado.'; end if;
  select * into me from profiles where id = auth.uid() for update;            -- serializa resgates da mesma pessoa
  select * into r from rewards where id = p_reward and active for update; if not found then raise exception 'Recompensa indisponível.'; end if;
  if r.stock is not null and r.stock <= 0 then raise exception 'Recompensa esgotada.'; end if;
  select id into per from periods where status = 'open';
  if r.per_user_limit > 0 then
    select count(*) into n from redemptions where reward_id = r.id and user_id = me.id and status <> 'cancelled' and (r.kind <> 'normal' or period_id = per);
    if n >= r.per_user_limit then raise exception 'Você atingiu o limite desta recompensa.'; end if;
  end if;
  if r.kind = 'avatar' and (r.payload->>'emoji') = any (me.unlocked_avatars) then raise exception 'Você já tem este avatar.'; end if;
  if balance_of(me.id) < r.cost then raise exception 'Saldo de moedas insuficiente.'; end if;
  insert into redemptions (request_key, reward_id, name, user_id, cost, period_id, status)
    values (p_key, r.id, r.name, me.id, r.cost, per, case when r.kind in ('avatar','title') then 'done' else 'pending' end) returning id into rid;
  insert into wallet_tx (user_id, type, amount, ref, reason) values (me.id, 'spend', -r.cost, rid::text, 'Resgate: ' || r.name);
  if r.stock is not null then update rewards set stock = stock - 1 where id = r.id; end if;
  if r.kind = 'avatar' then update profiles set unlocked_avatars = unlocked_avatars || (r.payload->>'emoji') where id = me.id; end if;
  if r.kind = 'title' then update profiles set title = coalesce(r.payload->>'title', '') where id = me.id; end if;
  perform aud('redeem', 'redemption', rid::text, r.name); return jsonb_build_object('ok', true, 'id', rid);
end $$;

create or replace function public.update_redemption(p_id uuid, p_action text) returns jsonb language plpgsql security definer set search_path = public as $$
declare r redemptions; adm boolean := is_admin();
begin
  perform need_member(); select * into r from redemptions where id = p_id for update; if not found then raise exception 'Resgate não encontrado.'; end if;
  if p_action = 'approve' then
    if r.status <> 'pending' then raise exception 'Este resgate não está pendente.'; end if;
    if r.user_id = auth.uid() then raise exception 'Outra pessoa precisa aprovar o seu resgate.'; end if;
    update redemptions set status = 'approved' where id = p_id;
  elsif p_action = 'done' then
    if r.status not in ('approved','pending') then raise exception 'Este resgate não pode ser concluído.'; end if;
    if r.user_id <> auth.uid() and not adm then raise exception 'Você não tem permissão para esta ação.'; end if;
    update redemptions set status = 'done' where id = p_id;
  elsif p_action = 'cancel' then
    if r.status in ('done','cancelled') then raise exception 'Este resgate não pode ser cancelado.'; end if;
    if r.user_id <> auth.uid() and not adm then raise exception 'Você não tem permissão para esta ação.'; end if;
    update redemptions set status = 'cancelled', refunded = true where id = p_id and not refunded;
    if found then
      insert into wallet_tx (user_id, type, amount, ref, reason) values (r.user_id, 'refund', r.cost, p_id::text, 'Estorno: ' || r.name);
      update rewards set stock = stock + 1 where id = r.reward_id and stock is not null;
    end if;
  else raise exception 'Ação inválida.'; end if;
  perform aud('redemption_' || p_action, 'redemption', p_id::text, ''); return jsonb_build_object('ok', true);
end $$;

create or replace function public.save_reward(p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare nm text := btrim(coalesce(p->>'name', '')); cst int; stk int; lim int; rid uuid := nullif(p->>'id', '')::uuid;
begin
  perform need_admin();
  if char_length(nm) < 2 then raise exception 'Informe o nome da recompensa.'; end if;
  cst := case when coalesce(p->>'cost','') ~ '^[0-9]+$' then (p->>'cost')::int end;
  if cst is null or cst > 10000 then raise exception 'Custo inválido.'; end if;
  if nullif(p->>'stock','') is not null then
    if p->>'stock' !~ '^[0-9]+$' then raise exception 'Estoque inválido.'; end if; stk := (p->>'stock')::int; end if;
  lim := case when coalesce(p->>'limit','') ~ '^[0-9]+$' then (p->>'limit')::int else 0 end;
  if rid is null then
    insert into rewards (name, description, cost, stock, per_user_limit, active) values (nm, left(coalesce(p->>'desc',''), 200), cst, stk, lim, coalesce((p->>'active')::boolean, true)) returning id into rid;
  else
    update rewards set name = nm, description = left(coalesce(p->>'desc',''), 200), cost = cst, stock = stk, per_user_limit = lim, active = coalesce((p->>'active')::boolean, true) where id = rid;
    if not found then raise exception 'Recompensa não encontrada.'; end if;
  end if;
  perform aud('reward', 'reward', rid::text, nm); return jsonb_build_object('ok', true);
end $$;

-- ======================= 13. ROLETA ==================================
create or replace function public.spin_wheel(p_mode text, p_category text default null, p_exclude uuid[] default '{}') returns jsonb
language plpgsql security definer set search_path = public as $$
declare pool jsonb; n int; i int; per uuid; res jsonb; rid uuid; opts text[]; lbl text;
begin
  perform need_member(); select id into per from periods where status = 'open';
  if p_mode = 'user' then
    select coalesce(jsonb_agg(jsonb_build_object('id', id, 'label', name, 'color', color, 'icon', avatar) order by name), '[]') into pool from profiles where active and plays and not (id = any (coalesce(p_exclude, '{}')));
  elsif p_mode = 'challenge' then
    select coalesce(jsonb_agg(jsonb_build_object('id', 'c' || (ord - 1), 'label', c) order by ord), '[]') into pool from settings, unnest(challenges) with ordinality as t(c, ord) where id = 1;
  elsif p_mode in ('task','category') then
    select coalesce(jsonb_agg(jsonb_build_object('id', o.id, 'label', o.title, 'icon', c.icon) order by o.due_date, o.title), '[]') into pool
      from occurrences o left join categories c on c.id = o.category_id
      where o.period_id = per and o.status in ('available','in_progress') and (p_mode <> 'category' or o.category_id = p_category);
  else raise exception 'Modo de sorteio inválido.'; end if;
  n := jsonb_array_length(pool);
  if n = 0 or (n = 1 and p_mode = 'user') then raise exception '%', case when n = 0 then 'Não há opções elegíveis para este sorteio.' else 'É preciso ao menos 2 opções para sortear.' end; end if;
  i := floor(random() * n)::int;
  select array_agg(e->>'label') into opts from jsonb_array_elements(pool) e;
  lbl := pool->i->>'label';
  insert into spins (mode, options, result, result_id, by_user) values (p_mode, opts, lbl, pool->i->>'id', auth.uid()) returning id into rid;
  perform aud('spin', 'spin', rid::text, lbl);
  return jsonb_build_object('ok', true, 'index', i, 'pool', pool);
end $$;

-- ======================= 14. PERFIL, AJUSTES, CATEGORIAS =============
create or replace function public.save_profile(p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare tid uuid := coalesce(nullif(p->>'id','')::uuid, auth.uid()); u profiles; nm text := btrim(coalesce(p->>'name', '')); av text := p->>'avatar'; co text := p->>'color';
begin
  perform need_member(); select * into u from profiles where id = tid for update; if not found then raise exception 'Participante inexistente.'; end if;
  if tid <> auth.uid() and not is_admin() then raise exception 'Você não tem permissão para esta ação.'; end if;
  if char_length(nm) not between 2 and 20 then raise exception 'O nome deve ter de 2 a 20 caracteres.'; end if;
  if exists (select 1 from profiles where id <> tid and active and lower(name) = lower(nm)) then raise exception 'Já existe um participante com esse nome.'; end if;
  if av is not null and av <> u.avatar then
    if char_length(av) > 12 then raise exception 'Avatar inválido.'; end if;
    if exists (select 1 from rewards where kind = 'avatar' and payload->>'emoji' = av) and not (av = any (u.unlocked_avatars)) then raise exception 'Este avatar precisa ser desbloqueado na loja.'; end if;
  end if;
  if co is not null and co !~ '^#[0-9A-Fa-f]{6}$' then raise exception 'Cor inválida.'; end if;
  if p ? 'plays' and p->>'plays' is not null and tid = auth.uid() and u.role = 'admin' then
    if (p->>'plays')::boolean and not u.plays and (select count(*) from profiles where active and plays) >= 4 then raise exception 'O jogo já tem 4 jogadores.'; end if;
    u.plays := (p->>'plays')::boolean;
  end if;
  update profiles set name = nm, avatar = coalesce(av, avatar), color = coalesce(co, color), plays = u.plays where id = tid;
  perform aud('update', 'user', tid::text, ''); return jsonb_build_object('ok', true);
end $$;

-- Só ativa/desativa jogadores. Há um único administrador: ninguém é promovido e o admin não pode ser desativado.
create or replace function public.admin_set_user(p_user uuid, p_active boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
declare u profiles;
begin
  perform need_admin(); select * into u from profiles where id = p_user for update; if not found then raise exception 'Participante inexistente.'; end if;
  if p_active is null or p_active = u.active then return jsonb_build_object('ok', true); end if;
  if u.role = 'admin' then raise exception 'O perfil de administrador não pode ser desativado.'; end if;
  if p_active and u.plays and (select count(*) from profiles where active and plays) >= 4 then raise exception 'O limite é de 4 participantes ativos.'; end if;
  update profiles set active = p_active where id = p_user;
  perform aud('update', 'user', p_user::text, case when p_active then 'reativado' else 'desativado' end);
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.save_settings(p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare s settings; pe jsonb; k text; v int;
begin
  perform need_admin(); select * into s from settings where id = 1 for update;
  if p ? 'appName' then
    if char_length(btrim(p->>'appName')) not between 2 and 30 then raise exception 'O nome do app deve ter de 2 a 30 caracteres.'; end if;
    update settings set app_name = btrim(p->>'appName') where id = 1; end if;
  if p ? 'prize' then
    if coalesce(p->>'prize','') !~ '^[0-9]+(\.[0-9]+)?$' or (p->>'prize')::numeric > 100000 then raise exception 'Valor do prêmio inválido.'; end if;
    update settings set prize = (p->>'prize')::numeric where id = 1; end if;
  if p ? 'restDays' then
    if coalesce(p->>'restDays','') !~ '^[0-9]+$' or (p->>'restDays')::int > 10 then raise exception 'Dias de descanso inválidos.'; end if;
    update settings set rest_days = (p->>'restDays')::int where id = 1; end if;
  if p ? 'shop' then update settings set shop_enabled = (p->>'shop')::boolean where id = 1; end if;
  if p ? 'openSignup' then update settings set open_signup = (p->>'openSignup')::boolean where id = 1; end if;
  if p ? 'coinRate' then
    if coalesce(p->>'coinRate','') !~ '^[0-9]+$' or (p->>'coinRate')::int > 10 then raise exception 'Taxa de moedas inválida.'; end if;
    update settings set coin_rate = (p->>'coinRate')::int where id = 1; end if;
  if p ? 'penalty' then
    pe := s.penalty;
    foreach k in array array['latePoints','missPoints','maxPerOcc','grace'] loop
      if p->'penalty' ? k then
        if coalesce(p->'penalty'->>k,'') !~ '^[0-9]+$' or (p->'penalty'->>k)::int > 100 then raise exception 'Valor de penalidade inválido.'; end if;
        pe := pe || jsonb_build_object(k, (p->'penalty'->>k)::int);
      end if;
    end loop;
    if p->'penalty' ? 'enabled' then pe := pe || jsonb_build_object('enabled', (p->'penalty'->>'enabled')::boolean); end if;
    update settings set penalty = pe where id = 1;
  end if;
  if p ? 'houseCode' then
    if char_length(btrim(p->>'houseCode')) not between 4 and 20 then raise exception 'O código da casa deve ter de 4 a 20 caracteres.'; end if;
    update app_secrets set house_code = upper(btrim(p->>'houseCode')) where id = 1; end if;
  if p ? 'challenges' then
    update settings set challenges = coalesce((select array_agg(left(btrim(c), 120)) from jsonb_array_elements_text(p->'challenges') c where btrim(c) <> ''), '{}') where id = 1; end if;
  perform aud('settings', 'settings', '', (select string_agg(key, ',') from jsonb_object_keys(p) key)); return jsonb_build_object('ok', true);
end $$;

create or replace function public.save_category(p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare nm text := btrim(coalesce(p->>'name', '')); cid text := nullif(p->>'id', '');
begin
  perform need_admin(); if char_length(nm) not between 2 and 30 then raise exception 'Nome de categoria inválido.'; end if;
  if cid is null then insert into categories (id, name, icon) values ('c' || substr(md5(random()::text), 1, 8), nm, left(coalesce(nullif(p->>'icon',''), '✨'), 4));
  else update categories set name = nm, icon = left(coalesce(nullif(p->>'icon',''), '✨'), 4) where id = cid; end if;
  perform aud('category', 'category', coalesce(cid, ''), nm); return jsonb_build_object('ok', true);
end $$;

-- Admin escolhe quais tarefas do catálogo valem (liga, desliga e ajusta pontos de uma vez). p = [{id, on, points}]
create or replace function public.apply_task_picks(p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare it jsonb; m catalog; tk tasks; has boolean; pts int; fr text; itv int; td date := today_br(); n_new int := 0; n_on int := 0; n_off int := 0;
begin
  perform need_admin();
  if p is null or jsonb_typeof(p) <> 'array' then raise exception 'Seleção inválida.'; end if;
  perform pg_advisory_xact_lock(7001);
  if not exists (select 1 from periods where status = 'open') then raise exception 'Nenhum período aberto.'; end if;
  for it in select * from jsonb_array_elements(p) loop
    select * into m from catalog where id = it->>'id'; if not found then raise exception 'Modelo não encontrado.'; end if;
    pts := case when coalesce(it->>'points','') ~ '^[0-9]+$' then (it->>'points')::int end;
    if pts is null or pts not between 1 and 500 then raise exception 'Pontuação inválida em "%" (1 a 500).', m.title; end if;
    update catalog set points = pts where id = m.id and points <> pts;
    select * into tk from tasks where frequency <> 'once' and lower(btrim(title)) = lower(btrim(m.title)) order by active desc, created_at limit 1;
    has := found;
    fr := case when m.freq = 'biweekly' then 'custom' else m.freq end; itv := case when m.freq = 'biweekly' then 14 end;
    if coalesce((it->>'on')::boolean, false) then
      if has then
        update tasks set points = pts, active = true, next_due = case when tk.active then tk.next_due else td end, updated_at = now(),
          log = log || log_item(case when tk.active then 'Pontos ajustados' else 'Reativada' end) where id = tk.id;
        if not tk.active then n_on := n_on + 1; end if;
      else
        insert into tasks (title, description, category_id, frequency, interval_days, points, assigned_to, next_due, anchor_day, active, log)
          values (m.title, '', m.category_id, fr, itv, pts, null, td, extract(day from td)::int, true, log_item('Criada'));
        n_new := n_new + 1;
      end if;
    elsif has and tk.active then
      update tasks set active = false, updated_at = now(), log = log || log_item('Pausada') where id = tk.id; n_off := n_off + 1;
    end if;
  end loop;
  perform gen_occurrences();
  perform aud('picks', 'task', '', n_new || ' novas, ' || n_on || ' reativadas, ' || n_off || ' pausadas');
  return jsonb_build_object('ok', true, 'created', n_new, 'enabled', n_on, 'paused', n_off);
end $$;

create or replace function public.save_catalog_points(p_id text, p_points int) returns jsonb language plpgsql security definer set search_path = public as $$
begin
  perform need_admin(); if p_points is null or p_points not between 1 and 500 then raise exception 'Pontuação inválida (1 a 500).'; end if;
  update catalog set points = p_points where id = p_id; if not found then raise exception 'Modelo não encontrado.'; end if;
  perform aud('catalog', 'catalog', p_id, p_points::text); return jsonb_build_object('ok', true);
end $$;

-- ======================= 15. PERMISSÕES DAS FUNÇÕES ==================
-- Tudo começa fechado; abrimos só o que o app precisa.
revoke execute on all functions in schema public from public, anon, authenticated;
grant execute on function public.public_status(), public.signup_problem(text, text, text) to anon, authenticated;
grant execute on function
  public.sweep(), public.create_task(jsonb), public.update_task_def(uuid, jsonb), public.delete_task_def(uuid),
  public.update_occurrence(uuid, jsonb), public.cancel_occurrence(uuid, text), public.claim_occurrence(uuid),
  public.assign_occurrence(uuid, uuid), public.start_occurrence(uuid), public.submit_evidence(uuid, text),
  public.review_occurrence(uuid, boolean, text), public.adjust_points(uuid, int, text, uuid), public.reverse_score(uuid, text),
  public.contest_penalty(uuid, text), public.resolve_contest(uuid, boolean, text), public.close_period(uuid, text),
  public.set_rest_day(uuid, date, text), public.set_prize_paid(uuid, boolean), public.redeem_reward(uuid, uuid),
  public.update_redemption(uuid, text), public.save_reward(jsonb), public.spin_wheel(text, text, uuid[]),
  public.save_profile(jsonb), public.admin_set_user(uuid, boolean), public.get_house_code(), public.save_settings(jsonb),
  public.save_category(jsonb), public.save_catalog_points(text, int), public.apply_task_picks(jsonb)
  to authenticated;
-- As políticas de RLS chamam is_member()/is_admin() e today_br() com o papel do usuário logado:
grant execute on function public.is_member(), public.is_admin(), public.today_br() to anon, authenticated;
revoke all on all tables in schema public from anon;
revoke all on all sequences in schema public from anon, authenticated;
revoke insert, update, delete, truncate, references, trigger on all tables in schema public from authenticated;
grant select on all tables in schema public to authenticated;
revoke select on public.admin_emails, public.app_secrets from authenticated;

-- ======================= 16. FOTOS (Storage) =========================
insert into storage.buckets (id, name, public) values ('evidence', 'evidence', false) on conflict (id) do nothing;
create policy "membros veem comprovacoes" on storage.objects for select to authenticated
  using (bucket_id = 'evidence' and public.is_member());
create policy "jogador envia a propria comprovacao" on storage.objects for insert to authenticated
  with check (bucket_id = 'evidence' and public.is_member() and (storage.foldername(name))[1] = auth.uid()::text);
