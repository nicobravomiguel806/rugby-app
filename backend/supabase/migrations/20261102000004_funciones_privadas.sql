-- SP-03 · Endurecimiento tras el linter de seguridad de Supabase (2 nov 2026)
-- 1) Las funciones auxiliares de permisos estaban en el esquema public, que PostgREST expone como
--    /rest/v1/rpc/*. Cualquiera (incluso anon, por los privilegios por defecto de Supabase) podía llamarlas;
--    es_menor(uuid) revelaba si un perfil es de un menor (AT-01, RNF-04).
--    Se mueven al esquema "privado", que la API no expone. Las políticas siguen funcionando porque
--    PostgreSQL las guarda por OID, no por nombre.
-- 2) eventos_inmutables() no tenía search_path fijo.

create schema if not exists privado;
revoke all on schema privado from public, anon;
grant usage on schema privado to authenticated;   -- necesario para evaluar las políticas

alter function public.es_admin_comunidad(uuid) set schema privado;
alter function public.es_master(uuid) set schema privado;
alter function public.es_admin_torneo(uuid) set schema privado;
alter function public.es_menor(uuid) set schema privado;
alter function public.es_tutor_de(uuid) set schema privado;
alter function public.es_staff_de(uuid, public.rol_en_equipo[]) set schema privado;
alter function public.es_staff_del_equipo(uuid) set schema privado;
alter function public.es_medico() set schema privado;
alter function public.mi_comunidad() set schema privado;
alter function public.puede_ver_perfil(uuid) set schema privado;
alter function public.es_oficial_de(uuid) set schema privado;

-- Estas dos llaman a otras auxiliares por nombre: se recrean apuntando a privado.
create or replace function privado.es_admin_torneo(t uuid) returns boolean
language sql stable security definer set search_path = public, pg_temp as $$
  select exists (select 1 from tournament_admins where tournament_id = t and profile_id = auth.uid())
      or exists (select 1 from tournaments tr where tr.id = t and privado.es_admin_comunidad(tr.community_id));
$$;

create or replace function privado.puede_ver_perfil(p uuid) returns boolean
language sql stable security definer set search_path = public, pg_temp as $$
  select p = auth.uid()
      or (not privado.es_menor(p) and (select community_id from profiles where id = p) = privado.mi_comunidad())
      or privado.es_tutor_de(p)
      or privado.es_staff_de(p)
      or privado.es_admin_comunidad((select community_id from profiles where id = p));
$$;

revoke all on all functions in schema privado from public, anon;
grant execute on all functions in schema privado to authenticated;

-- Solo la RPC de sincronización queda en la API, y solo para usuarios con sesión.
do $$ begin
  if exists (select 1 from pg_roles where rolname = 'anon') then
    execute 'revoke execute on function public.sync_match_events(jsonb) from anon';
  end if;
end $$;

create or replace function public.eventos_inmutables() returns trigger
language plpgsql set search_path = public, pg_temp as $$
begin
  raise exception 'match_events es de solo inserción: registra un evento de anulación (RNF-13)';
end $$;
revoke all on function public.eventos_inmutables() from public, anon, authenticated;
