-- =====================================================================
-- COMPROVAÇÃO SEM FOTO  (rode UMA vez no SQL Editor; pode repetir sem problema)
-- Modos: 'both' = foto ou "fiz sem foto" (outra pessoa confirma)  [padrão]
--        'photo' = só com foto
--        'trust' = sem foto, vale na hora (sem aprovação)
-- =====================================================================
alter table public.settings add column if not exists proof_mode text not null default 'both';
alter table public.settings drop constraint if exists settings_proof_mode_check;
alter table public.settings add constraint settings_proof_mode_check check (proof_mode in ('both','photo','trust'));

create or replace function public.set_proof_mode(p text) returns jsonb language plpgsql security definer set search_path = public as $$
begin
  perform need_admin();
  if p is null or p not in ('both','photo','trust') then raise exception 'Modo de comprovação inválido.'; end if;
  update settings set proof_mode = p where id = 1;
  perform aud('settings', 'proof_mode', '1', p);
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.submit_nophoto(p_occ uuid) returns jsonb language plpgsql security definer set search_path = public as $$
declare o occurrences; md text; rate int; coins int; ach text[];
begin
  perform need_member();
  select * into o from occurrences where id = p_occ for update; if not found then raise exception 'Tarefa não encontrada.'; end if;
  if o.assigned_to is distinct from auth.uid() then raise exception 'Só o responsável pode enviar a comprovação.'; end if;
  if o.status not in ('available','in_progress','rejected') then raise exception 'Esta tarefa não aceita novo envio agora.'; end if;
  if not exists (select 1 from periods where id = o.period_id and status = 'open') then raise exception 'O período desta tarefa foi encerrado.'; end if;
  select proof_mode, coin_rate into md, rate from settings where id = 1;
  if md = 'photo' then raise exception 'Neste jogo a comprovação é só por foto.'; end if;
  if md = 'trust' then
    if exists (select 1 from score_tx where occurrence_id = p_occ and type = 'task') then raise exception 'Os pontos desta tarefa já foram creditados.'; end if;
    update occurrences set status = 'done', completed_at = now(), submitted_by = auth.uid(), submitted_at = now(), reviewed_at = now(), photo_path = null,
      rejection_reason = '', log = log || log_item('Feita sem foto, aprovada na confiança, +' || o.points || ' pontos') where id = p_occ;
    insert into score_tx (user_id, occurrence_id, period_id, type, points, reason, created_by) values (o.assigned_to, p_occ, o.period_id, 'task', o.points, o.title, null);
    coins := o.points * coalesce(rate, 0);
    if coins > 0 then insert into wallet_tx (user_id, type, amount, ref, reason) values (o.assigned_to, 'earn', coins, p_occ::text, 'Tarefa: ' || o.title); end if;
    ach := check_achievements(o.assigned_to);
    perform aud('approve', 'occurrence', p_occ::text, 'sem foto, na confiança');
    return jsonb_build_object('ok', true, 'auto', true, 'points', o.points, 'achievements', to_jsonb(ach));
  end if;
  insert into evidence (occurrence_id, submitted_by, image_path) values (p_occ, auth.uid(), '');
  update occurrences set status = 'awaiting_approval', submitted_by = auth.uid(), submitted_at = now(), photo_path = null,
    rejection_reason = '', log = log || log_item('Marcada como feita, sem foto') where id = p_occ;
  perform aud('submit', 'occurrence', p_occ::text, 'sem foto');
  return jsonb_build_object('ok', true, 'auto', false);
end $$;

revoke execute on function public.set_proof_mode(text), public.submit_nophoto(uuid) from public, anon;
grant execute on function public.set_proof_mode(text), public.submit_nophoto(uuid) to authenticated;
