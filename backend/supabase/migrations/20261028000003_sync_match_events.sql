-- SP-02 · Sincronización idempotente de eventos de partido.
-- La app llama: supabase.rpc('sync_match_events', { p_events: [...] })
-- SECURITY INVOKER a propósito: las políticas RLS de match_events siguen aplicando (solo oficiales, solo en vivo).
-- Reenviar el mismo lote no duplica nada (ON CONFLICT (id) DO NOTHING) y devuelve los ids confirmados
-- para que el cliente los marque como sincronizados.

create or replace function public.sync_match_events(p_events jsonb)
returns setof uuid
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
begin
  if jsonb_typeof(p_events) <> 'array' or jsonb_array_length(p_events) > 200 then
    raise exception 'p_events debe ser un arreglo de hasta 200 eventos';
  end if;

  insert into match_events (id, match_id, type, team_side, roster_id, minute, period, points,
                            voids_event_id, created_by, client_ts, device_seq)
  select (e->>'id')::uuid, (e->>'match_id')::uuid, (e->>'type')::tipo_evento, e->>'team_side',
         nullif(e->>'roster_id','')::uuid, (e->>'minute')::int, coalesce((e->>'period')::int, 1),
         coalesce((e->>'points')::int, 0), nullif(e->>'voids_event_id','')::uuid,
         auth.uid(),                                 -- el autor lo pone el servidor, no el cliente (AT-04)
         (e->>'client_ts')::timestamptz, (e->>'device_seq')::bigint
  from jsonb_array_elements(p_events) e
  order by (e->>'device_seq')::bigint
  on conflict (id) do nothing;

  return query
    select me.id from match_events me
    where me.id in (select (e->>'id')::uuid from jsonb_array_elements(p_events) e)
      and me.created_by = auth.uid();
end $$;

revoke all on function public.sync_match_events(jsonb) from public;
grant execute on function public.sync_match_events(jsonb) to authenticated;
