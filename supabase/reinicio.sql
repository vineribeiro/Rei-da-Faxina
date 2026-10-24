-- =====================================================================
-- REINÍCIO GERAL + TAREFAS FIXAS POR DIA DA SEMANA  (rode UMA vez no SQL Editor)
-- O jogo começa em 01/11/2026. Mantém: contas, categorias, tabela de pontos e loja.
-- Apaga: tarefas, pontos, moedas, resgates, conquistas, histórico, sorteios, bichinhos e períodos.
-- Pode rodar de novo com segurança (refaz o reinício).
-- =====================================================================
begin;

-- 1) Estrutura nova ---------------------------------------------------
alter table public.settings add column if not exists game_start date;
alter table public.tasks add column if not exists weekdays int[];
alter table public.tasks drop constraint if exists tasks_frequency_check;
alter table public.tasks add constraint tasks_frequency_check
  check (frequency in ('once','daily','weekly','monthly','custom','days'));

create or replace function public.next_wd(d date, wd int[]) returns date language plpgsql immutable as $$
declare x date := d; g int := 0;
begin
  if wd is null or cardinality(wd) = 0 then return d; end if;
  while g < 8 and not (extract(dow from x)::int = any (wd)) loop x := x + 1; g := g + 1; end loop;
  return x;
end $$;

create or replace function public.adv_task(freq text, d date, anchor int, itv int, wd int[]) returns date language sql immutable as $$
  select case when freq = 'days' then public.next_wd(d + 1, wd) else public.adv_date(freq, d, anchor, itv) end $$;

-- 2) Recorrência respeita a data de início e os dias da semana -------------
create or replace function public.gen_occurrences() returns int language plpgsql security definer set search_path = public as $$
declare d tasks; per uuid; td date := today_br(); due date; lst date; g int; n int := 0; gs date;
begin
  select game_start into gs from settings where id = 1;
  if gs is not null and td < gs then return 0; end if;
  select id into per from periods where status = 'open'; if per is null then return 0; end if;
  for d in select * from tasks where active and frequency <> 'once' and next_due is not null and next_due <= td for update loop
    due := d.next_due; lst := null; g := 0;
    while due <= td and g < 800 loop lst := due; due := adv_task(d.frequency, due, d.anchor_day, d.interval_days, d.weekdays); g := g + 1; end loop;
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

create or replace function public.check_task_payload(p jsonb, is_new boolean) returns void language plpgsql stable security definer set search_path = public as $$
declare t text := btrim(coalesce(p->>'title','')); pts int; fr text := p->>'frequency'; due date; itv int;
begin
  if char_length(t) not between 2 and 80 then raise exception 'Informe um nome com 2 a 80 caracteres.'; end if;
  pts := case when coalesce(p->>'points','') ~ '^[0-9]+$' then (p->>'points')::int end;
  if pts is null or pts not between 1 and 500 then raise exception 'A pontuação deve ser um número inteiro de 1 a 500.'; end if;
  if not exists (select 1 from categories where id = p->>'categoryId') then raise exception 'Categoria inválida.'; end if;
  if fr is null or fr not in ('once','daily','weekly','monthly','custom','days') then raise exception 'Frequência inválida.'; end if;
  if fr = 'custom' then
    itv := case when coalesce(p->>'interval','') ~ '^[0-9]+$' then (p->>'interval')::int end;
    if itv is null or itv not between 2 and 365 then raise exception 'Informe o intervalo em dias (2 a 365).'; end if;
  end if;
  if fr = 'days' and (jsonb_typeof(p->'weekdays') is distinct from 'array' or jsonb_array_length(p->'weekdays') = 0) then
    raise exception 'Escolha pelo menos um dia da semana.'; end if;
  begin due := (p->>'dueDate')::date; exception when others then due := null; end;
  if due is null then raise exception 'Informe um prazo válido.'; end if;
  if is_new and due < today_br() then raise exception 'O prazo não pode estar no passado.'; end if;
  if nullif(p->>'assignedTo','') is not null and not player_ok((p->>'assignedTo')::uuid) then raise exception 'Responsável inexistente ou inativo.'; end if;
end $$;

create or replace function public.wd_array(p jsonb) returns int[] language sql immutable as $$
  select case when jsonb_typeof(p->'weekdays') = 'array'
    then (select array_agg(distinct v order by v) from (select (x)::int v from jsonb_array_elements_text(p->'weekdays') x) q where v between 0 and 6) end $$;

create or replace function public.create_task(p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare tid uuid; per uuid; due date; fr text; t text; asg uuid; wd int[];
begin
  perform need_admin(); perform check_task_payload(p, true);
  t := btrim(p->>'title'); due := (p->>'dueDate')::date; fr := p->>'frequency'; asg := nullif(p->>'assignedTo','')::uuid;
  wd := case when fr = 'days' then wd_array(p) end;
  if fr = 'days' then due := next_wd(due, wd); end if;
  select id into per from periods where status = 'open'; if per is null then raise exception 'Nenhum período aberto.'; end if;
  if exists (select 1 from occurrences where lower(btrim(title)) = lower(t) and due_date = due and status <> 'cancelled') then
    raise exception 'Já existe uma tarefa com esse nome e esse prazo.'; end if;
  insert into tasks (title, description, category_id, frequency, interval_days, weekdays, points, assigned_to, next_due, anchor_day, active, log)
    values (t, left(btrim(coalesce(p->>'desc','')), 300), p->>'categoryId', fr, case when fr = 'custom' then (p->>'interval')::int end, wd,
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
declare d tasks; wd int[];
begin
  perform need_admin(); select * into d from tasks where id = p_id for update; if not found then raise exception 'Tarefa não encontrada.'; end if;
  perform check_task_payload(p, false);
  wd := case when p->>'frequency' = 'days' then wd_array(p) end;
  update tasks set title = btrim(p->>'title'), description = left(btrim(coalesce(p->>'desc','')), 300), category_id = p->>'categoryId',
    points = (p->>'points')::int, assigned_to = nullif(p->>'assignedTo','')::uuid, frequency = p->>'frequency',
    interval_days = case when p->>'frequency' = 'custom' then (p->>'interval')::int end, weekdays = wd,
    active = coalesce((p->>'active')::boolean, active),
    next_due = case when p->>'frequency' = 'once' then next_due
                    when p->>'frequency' = 'days' then next_wd((p->>'dueDate')::date, wd) else (p->>'dueDate')::date end,
    updated_at = now(), log = log || log_item('Editada') where id = p_id;
  perform aud('update', 'task', p_id::text, '');
  return jsonb_build_object('ok', true);
end $$;

-- 3) REINÍCIO: apaga o andamento e começa em 01/11/2026 ------------------
delete from public.evidence;
delete from public.score_tx;
delete from public.wallet_tx;
delete from public.redemptions;
delete from public.achievements_unlocked;
delete from public.rest_days;
delete from public.spins;
delete from public.occurrences;
delete from public.tasks;
delete from public.periods;
delete from public.audit_log;
delete from public.pets;

update public.settings set game_start = date '2026-11-01' where id = 1;
insert into public.periods (start_date, end_date) values (date '2026-11-01', date '2026-11-30');

-- 4) TAREFAS FIXAS (cada uma já vem atribuída; dias: 0=dom 1=seg 2=ter 3=qua 4=qui 5=sex 6=sáb) ---
do $$
declare davi uuid; camila uuid; vini uuid; g date := date '2026-11-01';
begin
  select id into davi   from profiles where active and plays and lower(name) like 'davi%'   order by created_at limit 1;
  select id into camila from profiles where active and plays and lower(name) like 'camila%' order by created_at limit 1;
  select id into vini   from profiles where active and plays and (lower(name) like 'vinicius%' or lower(name) like 'vine%' or lower(name) like 'vini%') order by created_at limit 1;
  if davi is null or camila is null or vini is null then
    raise exception 'Não achei o perfil de: % % %. Nomes cadastrados: %',
      case when davi is null then 'Davi' else '' end, case when camila is null then 'Camila' else '' end, case when vini is null then 'Vinicius/Vine' else '' end,
      (select string_agg(name, ', ') from profiles where active);
  end if;

  insert into tasks (title, description, category_id, frequency, weekdays, points, assigned_to, next_due, anchor_day, active, log)
  select t.title, t.descr, t.cat, t.fr, t.wd, t.pts, t.who, public.next_wd(g, coalesce(t.wd, array[0,1,2,3,4,5,6])), 1, true,
         jsonb_build_array(jsonb_build_object('at', now(), 'by', 'system', 'text', 'Tarefa fixa'))
  from (values
    ('Arrumar a cama',                       'Todos os dias',                      'quarto',     'daily', null::int[],      5,  davi),
    ('Trocar a roupa de cama',               'Todo sábado',                        'quarto',     'days',  array[6],         15, davi),
    ('Limpar as caixinhas das gatas',        'Todos os dias',                      'animais',    'daily', null::int[],      10, davi),
    ('Lavar a louça (pratos e talheres)',    'Todos os dias',                      'cozinha',    'daily', null::int[],      10, davi),
    ('Passar aspirador na sala',             'Segunda, quarta e sexta',            'sala',       'days',  array[1,3,5],     15, davi),
    ('Arrumar o quarto',                     'Terça e sexta',                      'quarto',     'days',  array[2,5],       15, davi),
    ('Arrumar a cama',                       'Todos os dias',                      'quarto',     'daily', null::int[],      5,  camila),
    ('Dar água às plantas',                  'Terça e sexta',                      'organizacao','days',  array[2,5],       5,  camila),
    ('Sair com a Shakira',                   'Passeio com a cachorra, todos os dias','animais',  'daily', null::int[],      10, vini),
    ('Limpar a área dos pets',               'Todos os dias',                      'animais',    'daily', null::int[],      10, vini)
  ) as t(title, descr, cat, fr, wd, pts, who);
end $$;

commit;
-- Conferir: select title, frequency, weekdays, next_due, (select name from profiles where id = assigned_to) from tasks order by 5, 1;
