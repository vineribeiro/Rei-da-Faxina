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

create or replace function public.pet_save(p_state jsonb, p_spend int, p_reason text) returns jsonb language plpgsql as $$
begin raise exception 'Aplique audit-upgrade.sql e atualize o app para cuidar do Faxinho.'; end $$;

revoke execute on function public.pet_save(jsonb, int, text) from public, anon, authenticated;
revoke insert, update, delete, truncate, references, trigger on public.pets from authenticated, anon;
grant select on public.pets to authenticated;
