-- ============================================================
-- Rei da Faxina: bichinho (Faxinho)
-- Rode UMA vez no SQL Editor do Supabase (Run). Pode rodar de novo sem problema.
-- ============================================================
create table if not exists public.pets (
  id uuid primary key references public.profiles(id) on delete cascade,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
alter table public.pets enable row level security;
drop policy if exists "membros leem" on public.pets;
create policy "membros leem" on public.pets for select to authenticated using (public.is_member());

create or replace function public.pet_save(p_state jsonb, p_spend int, p_reason text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare me profiles; bal int;
begin
  if not player_ok(auth.uid()) then raise exception 'Apenas jogadores têm Faxinho.'; end if;
  if p_state is null or jsonb_typeof(p_state) <> 'object' or length(p_state::text) > 30000 then raise exception 'Dados do Faxinho inválidos.'; end if;
  if p_spend < 0 or p_spend > 500 then raise exception 'Valor inválido.'; end if;
  select * into me from profiles where id = auth.uid() for update;          -- serializa gastos da mesma pessoa
  if p_spend > 0 then
    select coalesce(sum(amount), 0) into bal from wallet_tx where user_id = me.id;
    if bal < p_spend then raise exception 'Moedas insuficientes.'; end if;
    insert into wallet_tx (user_id, type, amount, ref, reason) values (me.id, 'spend', -p_spend, 'pet', left(coalesce(p_reason, ''), 120));
  end if;
  insert into pets (id, data, updated_at) values (me.id, p_state, now())
    on conflict (id) do update set data = excluded.data, updated_at = now();
  return jsonb_build_object('ok', true);
end $$;

revoke execute on function public.pet_save(jsonb, int, text) from public, anon;
grant execute on function public.pet_save(jsonb, int, text) to authenticated;
revoke insert, update, delete, truncate, references, trigger on public.pets from authenticated, anon;
grant select on public.pets to authenticated;
