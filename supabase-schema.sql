-- Casa em Jogo: esquema para Supabase (Postgres + Auth + Storage)
-- Cada participante tem login próprio (Supabase Auth) e só enxerga/altera o que as políticas permitem.
-- Pontos só mudam por funções SECURITY DEFINER; o cliente nunca grava pontuação direto.

create extension if not exists "pgcrypto";

-- ===== perfis (1 por usuário do Auth) =====
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null check (char_length(name) between 2 and 20),
  avatar text not null default '🦊',
  color text not null default '#2B63E8',
  role text not null default 'user' check (role in ('admin','user')),
  active boolean not null default true,
  title text not null default '',
  unlocked_avatars text[] not null default '{}',
  created_at timestamptz not null default now()
);
create unique index profiles_name_active on public.profiles (lower(name)) where active;

create table public.settings (
  id int primary key default 1 check (id = 1),
  app_name text not null default 'Casa em Jogo',
  prize numeric(10,2) not null default 50,
  rest_days int not null default 2,
  shop_enabled boolean not null default true,
  coin_rate int not null default 1,
  penalty jsonb not null default '{"enabled":false,"latePoints":0,"missPoints":0,"maxPerOcc":5,"grace":1}',
  challenges text[] not null default '{}'
);
insert into public.settings default values on conflict do nothing;

create table public.categories (id text primary key, name text not null, icon text not null default '✨');

create table public.periods (
  id uuid primary key default gen_random_uuid(),
  start_date date not null, end_date date not null,
  status text not null default 'open' check (status in ('open','closed')),
  winner_id uuid references public.profiles(id),
  prize_amount numeric(10,2) not null default 0,
  prize_paid boolean not null default false,
  tie_resolution jsonb,
  closed_at timestamptz
);
create unique index one_open_period on public.periods (status) where status = 'open';

create table public.tasks (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(title) between 2 and 80),
  description text not null default '',
  category_id text references public.categories(id),
  frequency text not null check (frequency in ('once','daily','weekly','monthly','custom')),
  interval_days int, points int not null check (points between 1 and 500),
  assigned_to uuid references public.profiles(id),
  next_due date, anchor_day int, active boolean not null default true,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
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
  late_penalized boolean not null default false, miss_penalized boolean not null default false,
  completed_at timestamptz, created_at timestamptz not null default now(),
  unique (task_id, due_date)
);

create table public.evidence (
  id uuid primary key default gen_random_uuid(),
  occurrence_id uuid not null references public.occurrences(id),
  submitted_by uuid not null references public.profiles(id),
  image_path text not null,                       -- caminho no bucket "evidence"
  submitted_at timestamptz not null default now(),
  review_status text not null default 'pending' check (review_status in ('pending','approved','rejected')),
  reviewed_by uuid references public.profiles(id), reviewed_at timestamptz,
  rejection_reason text
);

create table public.score_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id),
  occurrence_id uuid references public.occurrences(id),
  period_id uuid not null references public.periods(id),
  type text not null check (type in ('task','adjust','penalty','reversal')),
  points int not null, reason text not null default '',
  ref_tx uuid references public.score_transactions(id), reversed_by uuid,
  post_close boolean not null default false,
  created_by uuid references public.profiles(id), created_at timestamptz not null default now()
);
-- garante pontuação única por ocorrência
create unique index one_task_score_per_occurrence on public.score_transactions (occurrence_id) where type = 'task';

create table public.wallet_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id),
  type text not null check (type in ('earn','spend','refund','bonus','reversal')),
  amount int not null, ref uuid, reason text not null default '',
  created_at timestamptz not null default now()
);

create table public.rewards (
  id uuid primary key default gen_random_uuid(),
  name text not null, description text not null default '',
  cost int not null check (cost >= 0), stock int check (stock >= 0),
  kind text not null default 'normal', payload text, per_user_limit int not null default 0,
  active boolean not null default true
);
create table public.redemptions (
  id uuid primary key default gen_random_uuid(),
  request_key uuid not null unique,                -- idempotência contra duplo clique
  reward_id uuid not null references public.rewards(id),
  user_id uuid not null references public.profiles(id),
  cost int not null, status text not null default 'pending'
    check (status in ('pending','approved','done','cancelled')),
  refunded boolean not null default false, created_at timestamptz not null default now()
);

create table public.achievements_unlocked (
  user_id uuid references public.profiles(id), achievement_id text, unlocked_at timestamptz not null default now(),
  primary key (user_id, achievement_id)
);
create table public.rest_days (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id), period_id uuid not null references public.periods(id),
  date date, status text not null default 'pending' check (status in ('pending','scheduled','used'))
);
create table public.spins (
  id uuid primary key default gen_random_uuid(), mode text not null, options text[] not null,
  result text not null, by_user uuid references public.profiles(id), created_at timestamptz not null default now()
);
create table public.audit_log (
  id bigint generated always as identity primary key,
  actor_id uuid, action text not null, entity_type text, entity_id text, reason text,
  created_at timestamptz not null default now()
);

-- ===== helpers =====
create or replace function public.is_admin() returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles where id = auth.uid() and role = 'admin' and active)
$$;
create or replace function public.is_member() returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles where id = auth.uid() and active)
$$;

-- ===== RLS =====
do $$ declare t text; begin
  foreach t in array array['profiles','settings','categories','periods','tasks','occurrences','evidence','score_transactions',
    'wallet_transactions','rewards','redemptions','achievements_unlocked','rest_days','spins','audit_log'] loop
    execute format('alter table public.%I enable row level security', t);
    -- todos os membros leem (ranking e histórico são transparentes)
    execute format('create policy "members read" on public.%I for select using (public.is_member())', t);
  end loop;
end $$;

-- Escritas diretas: só admin em cadastros; nada direto em pontos, moedas, resgates, evidências e auditoria.
create policy "admin writes categories" on public.categories for all using (public.is_admin()) with check (public.is_admin());
create policy "admin writes tasks" on public.tasks for all using (public.is_admin()) with check (public.is_admin());
create policy "admin writes rewards" on public.rewards for all using (public.is_admin()) with check (public.is_admin());
create policy "admin writes settings" on public.settings for update using (public.is_admin());
create policy "admin edits occurrences" on public.occurrences for update using (public.is_admin() and status in ('available','in_progress','rejected'));
create policy "own profile" on public.profiles for update using (id = auth.uid())
  with check (id = auth.uid() and role = (select role from profiles where id = auth.uid()));
create policy "admin profiles" on public.profiles for update using (public.is_admin());
create policy "admin rest days" on public.rest_days for update using (public.is_admin());

-- ===== funções atômicas (única porta de entrada para pontos) =====
create or replace function public.submit_evidence(p_occ uuid, p_path text) returns void
language plpgsql security definer set search_path = public as $$
declare o occurrences;
begin
  select * into o from occurrences where id = p_occ for update;
  if o.assigned_to is distinct from auth.uid() then raise exception 'Só o responsável pode enviar'; end if;
  if o.status not in ('available','in_progress','rejected') then raise exception 'Tarefa não aceita novo envio'; end if;
  if not exists (select 1 from periods where id = o.period_id and status = 'open') then raise exception 'Período encerrado'; end if;
  insert into evidence (occurrence_id, submitted_by, image_path) values (p_occ, auth.uid(), p_path);
  update occurrences set status = 'awaiting_approval' where id = p_occ;
  insert into audit_log (actor_id, action, entity_type, entity_id) values (auth.uid(), 'submit', 'occurrence', p_occ::text);
end $$;

create or replace function public.review_occurrence(p_occ uuid, p_approve boolean, p_reason text default null) returns void
language plpgsql security definer set search_path = public as $$
declare o occurrences; ev evidence; coins int; rate int;
begin
  if not is_member() then raise exception 'Sem acesso'; end if;
  select * into o from occurrences where id = p_occ for update;
  if o.status <> 'awaiting_approval' then raise exception 'Tarefa não está aguardando aprovação'; end if;
  select * into ev from evidence where occurrence_id = p_occ and review_status = 'pending' order by submitted_at desc limit 1;
  if ev.submitted_by = auth.uid() or o.assigned_to = auth.uid() then raise exception 'Você não pode aprovar a própria tarefa'; end if;
  if p_approve then
    if o.assigned_to is null then raise exception 'Tarefa sem responsável não pontua'; end if;
    update occurrences set status = 'done', completed_at = now() where id = p_occ;
    update evidence set review_status = 'approved', reviewed_by = auth.uid(), reviewed_at = now() where id = ev.id;
    insert into score_transactions (user_id, occurrence_id, period_id, type, points, reason, created_by)
      values (o.assigned_to, p_occ, o.period_id, 'task', o.points, o.title, auth.uid());   -- índice único impede duplicar
    select coin_rate into rate from settings where id = 1; coins := o.points * rate;
    if coins > 0 then insert into wallet_transactions (user_id, type, amount, ref, reason) values (o.assigned_to, 'earn', coins, p_occ, o.title); end if;
  else
    if coalesce(char_length(trim(p_reason)), 0) < 3 then raise exception 'Informe o motivo'; end if;
    update occurrences set status = 'rejected' where id = p_occ;
    update evidence set review_status = 'rejected', reviewed_by = auth.uid(), reviewed_at = now(), rejection_reason = p_reason where id = ev.id;
  end if;
  insert into audit_log (actor_id, action, entity_type, entity_id, reason)
    values (auth.uid(), case when p_approve then 'approve' else 'reject' end, 'occurrence', p_occ::text, p_reason);
end $$;

create or replace function public.adjust_points(p_user uuid, p_period uuid, p_delta int, p_reason text) returns void
language plpgsql security definer set search_path = public as $$
declare closed boolean;
begin
  if not is_admin() then raise exception 'Apenas administradores'; end if;
  if p_delta = 0 or abs(p_delta) > 500 then raise exception 'Ajuste inválido'; end if;
  if coalesce(char_length(trim(p_reason)), 0) < 3 then raise exception 'Justificativa obrigatória'; end if;
  select status = 'closed' into closed from periods where id = p_period;
  insert into score_transactions (user_id, period_id, type, points, reason, post_close, created_by)
    values (p_user, p_period, 'adjust', p_delta, p_reason, closed, auth.uid());
  insert into audit_log (actor_id, action, entity_type, entity_id, reason)
    values (auth.uid(), case when closed then 'adjust_closed' else 'adjust' end, 'user', p_user::text, p_reason);
end $$;

create or replace function public.reverse_score(p_tx uuid, p_reason text) returns void
language plpgsql security definer set search_path = public as $$
declare t score_transactions; rid uuid; closed boolean;
begin
  if not is_admin() then raise exception 'Apenas administradores'; end if;
  select * into t from score_transactions where id = p_tx for update;
  if t.type = 'reversal' or t.reversed_by is not null then raise exception 'Registro já estornado'; end if;
  if coalesce(char_length(trim(p_reason)), 0) < 3 then raise exception 'Justificativa obrigatória'; end if;
  select status = 'closed' into closed from periods where id = t.period_id;
  insert into score_transactions (user_id, occurrence_id, period_id, type, points, reason, ref_tx, post_close, created_by)
    values (t.user_id, null, t.period_id, 'reversal', -t.points, p_reason, t.id, closed, auth.uid()) returning id into rid;
  update score_transactions set reversed_by = rid where id = p_tx;
  insert into audit_log (actor_id, action, entity_type, entity_id, reason) values (auth.uid(), 'reverse', 'score', p_tx::text, p_reason);
end $$;

create or replace function public.redeem_reward(p_reward uuid, p_key uuid) returns uuid
language plpgsql security definer set search_path = public as $$
declare r rewards; bal int; rid uuid;
begin
  if exists (select 1 from redemptions where request_key = p_key) then raise exception 'Resgate já processado'; end if;
  select * into r from rewards where id = p_reward and active for update;
  if not found then raise exception 'Recompensa indisponível'; end if;
  if r.stock is not null and r.stock <= 0 then raise exception 'Esgotada'; end if;
  perform 1 from profiles where id = auth.uid() for update;           -- serializa resgates da mesma pessoa
  select coalesce(sum(amount), 0) into bal from wallet_transactions where user_id = auth.uid();
  if bal < r.cost then raise exception 'Saldo insuficiente'; end if;
  insert into redemptions (request_key, reward_id, user_id, cost) values (p_key, p_reward, auth.uid(), r.cost) returning id into rid;
  insert into wallet_transactions (user_id, type, amount, ref, reason) values (auth.uid(), 'spend', -r.cost, rid, 'Resgate: ' || r.name);
  if r.stock is not null then update rewards set stock = stock - 1 where id = r.id; end if;
  return rid;
end $$;

create or replace function public.cancel_redemption(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare r redemptions;
begin
  select * into r from redemptions where id = p_id for update;
  if r.status in ('done','cancelled') then raise exception 'Não pode ser cancelado'; end if;
  if r.user_id <> auth.uid() and not is_admin() then raise exception 'Sem permissão'; end if;
  update redemptions set status = 'cancelled', refunded = true where id = p_id and not refunded;
  if found then
    insert into wallet_transactions (user_id, type, amount, ref, reason) values (r.user_id, 'refund', r.cost, p_id, 'Estorno de resgate');
    update rewards set stock = stock + 1 where id = r.reward_id and stock is not null;
  end if;
end $$;

-- Ranking calculado sempre a partir das transações oficiais
create or replace view public.ranking as
select s.period_id, s.user_id, p.name,
  sum(s.points) as points,
  count(*) filter (where s.type = 'task' and s.reversed_by is null) as tasks,
  coalesce(sum(s.points) filter (where s.type = 'task' and s.reversed_by is null and o.recurring), 0) as recurring_points
from score_transactions s join profiles p on p.id = s.user_id left join occurrences o on o.id = s.occurrence_id
group by s.period_id, s.user_id, p.name;

-- ===== Storage: fotos de comprovação =====
insert into storage.buckets (id, name, public) values ('evidence', 'evidence', false) on conflict do nothing;
create policy "members read evidence" on storage.objects for select using (bucket_id = 'evidence' and public.is_member());
create policy "upload own evidence" on storage.objects for insert
  with check (bucket_id = 'evidence' and public.is_member() and (storage.foldername(name))[1] = auth.uid()::text);

-- Ainda por implementar no servidor (hoje só existem no app local): encerramento mensal (close_period),
-- geração de recorrências e penalidades (agendar com pg_cron), conquistas. Seguem a mesma regra: função
-- SECURITY DEFINER, checagem de perfil, auditoria e unicidade por índice.
