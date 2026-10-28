-- SP-03 · Row Level Security por rol (RNF-02, RNF-04, RNF-13)
-- Principio: todo cerrado por defecto. Cada tabla tiene RLS activa y solo se abre lo que una historia necesita.
-- Las funciones auxiliares son SECURITY DEFINER con search_path fijo para evitar secuestro de funciones
-- y recursión de políticas (ver docs/security/threat-model.md, AT-05).

-- ── Funciones auxiliares ────────────────────────────────────────────────────────
create or replace function public.es_admin_comunidad(c uuid) returns boolean
language sql stable security definer set search_path = public, pg_temp as $$
  select exists (select 1 from admin_roles where profile_id = auth.uid() and community_id = c
                 and role in ('masteruser','director'));
$$;

create or replace function public.es_master(c uuid) returns boolean
language sql stable security definer set search_path = public, pg_temp as $$
  select exists (select 1 from admin_roles where profile_id = auth.uid() and community_id = c and role = 'masteruser');
$$;

create or replace function public.es_admin_torneo(t uuid) returns boolean
language sql stable security definer set search_path = public, pg_temp as $$
  select exists (select 1 from tournament_admins where tournament_id = t and profile_id = auth.uid())
      or exists (select 1 from tournaments tr where tr.id = t and public.es_admin_comunidad(tr.community_id));
$$;

create or replace function public.es_menor(p uuid) returns boolean
language sql stable security definer set search_path = public, pg_temp as $$
  select coalesce((select birth_date > (current_date - interval '18 years') from profiles where id = p), false);
$$;

create or replace function public.es_tutor_de(menor uuid) returns boolean
language sql stable security definer set search_path = public, pg_temp as $$
  select exists (select 1 from guardianships where guardian_id = auth.uid() and minor_id = menor and status = 'aprobada');
$$;

-- Staff (entrenador, manager o médico aprobado) de un equipo donde el perfil es miembro aprobado
create or replace function public.es_staff_de(p uuid, roles public.rol_en_equipo[] default '{entrenador,manager,medico}') returns boolean
language sql stable security definer set search_path = public, pg_temp as $$
  select exists (
    select 1 from team_memberships yo
    join team_memberships el on el.team_id = yo.team_id and el.profile_id = p and el.status = 'aprobada'
    where yo.profile_id = auth.uid() and yo.status = 'aprobada' and yo.role = any(roles));
$$;

create or replace function public.es_staff_del_equipo(t uuid) returns boolean
language sql stable security definer set search_path = public, pg_temp as $$
  select exists (select 1 from team_memberships where team_id = t and profile_id = auth.uid()
                 and status = 'aprobada' and role in ('entrenador','manager'));
$$;

create or replace function public.es_medico() returns boolean
language sql stable security definer set search_path = public, pg_temp as $$
  select exists (select 1 from profile_types where profile_id = auth.uid() and type = 'medico');
$$;

create or replace function public.mi_comunidad() returns uuid
language sql stable security definer set search_path = public, pg_temp as $$
  select community_id from profiles where id = auth.uid();
$$;

-- Un menor solo es visible para él mismo, sus tutores, el staff de su equipo y los administradores de su comunidad
create or replace function public.puede_ver_perfil(p uuid) returns boolean
language sql stable security definer set search_path = public, pg_temp as $$
  select p = auth.uid()
      or (not public.es_menor(p) and (select community_id from profiles where id = p) = public.mi_comunidad())
      or public.es_tutor_de(p)
      or public.es_staff_de(p)
      or public.es_admin_comunidad((select community_id from profiles where id = p));
$$;

create or replace function public.es_oficial_de(m uuid) returns boolean
language sql stable security definer set search_path = public, pg_temp as $$
  select exists (select 1 from match_officials where match_id = m and profile_id = auth.uid()
                 and role in ('arbitro','anotador'));
$$;

revoke all on all functions in schema public from public;
grant execute on all functions in schema public to authenticated;

-- ── Activar RLS en todas las tablas ─────────────────────────────────────────────
do $$ declare t text; begin
  for t in select tablename from pg_tables where schemaname = 'public' loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;

grant usage on schema public to authenticated, anon;
grant select, insert, update, delete on all tables in schema public to authenticated;
revoke all on all tables in schema public from anon;  -- la app siempre requiere sesión

-- ── Comunidad y perfiles ────────────────────────────────────────────────────────
create policy comunidades_lectura on communities for select to authenticated using (true);

create policy perfiles_lectura on profiles for select to authenticated using (public.puede_ver_perfil(id));
create policy perfiles_alta on profiles for insert to authenticated with check (id = auth.uid());
create policy perfiles_edicion on profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

create policy tipos_lectura on profile_types for select to authenticated using (public.puede_ver_perfil(profile_id));
-- Nadie se otorga a sí mismo el tipo "medico": lo asigna un administrador de la comunidad (AT-03)
create policy tipos_alta on profile_types for insert to authenticated
  with check ((profile_id = auth.uid() and type <> 'medico')
              or public.es_admin_comunidad((select community_id from profiles where id = profile_id)));
create policy tipos_baja on profile_types for delete to authenticated using (profile_id = auth.uid());

create policy jugador_lectura on player_details for select to authenticated using (public.puede_ver_perfil(profile_id));
create policy jugador_escritura on player_details for all to authenticated
  using (profile_id = auth.uid() or public.es_tutor_de(profile_id))
  with check (profile_id = auth.uid() or public.es_tutor_de(profile_id));

create policy tutela_lectura on guardianships for select to authenticated
  using (guardian_id = auth.uid() or minor_id = auth.uid()
         or public.es_admin_comunidad((select community_id from profiles where id = minor_id)));
create policy tutela_solicitud on guardianships for insert to authenticated
  with check (guardian_id = auth.uid() and status = 'pendiente');
-- Solo un administrador valida la tutela (C-05); el tutor no puede aprobarse a sí mismo
create policy tutela_validacion on guardianships for update to authenticated
  using (public.es_admin_comunidad((select community_id from profiles where id = minor_id)))
  with check (public.es_admin_comunidad((select community_id from profiles where id = minor_id)));

-- Datos médicos (RNF-04): el propio jugador, sus tutores y el médico del equipo. Nadie más.
create policy medico_lectura on medical_records for select to authenticated
  using (player_id = auth.uid() or public.es_tutor_de(player_id) or medic_id = auth.uid()
         or (public.es_medico() and public.es_staff_de(player_id, '{medico}')));
create policy medico_alta on medical_records for insert to authenticated
  with check (medic_id = auth.uid() and public.es_medico() and public.es_staff_de(player_id, '{medico}'));
-- Sin políticas de update/delete: un registro médico se corrige con uno nuevo.

create policy roles_lectura on admin_roles for select to authenticated
  using (profile_id = auth.uid() or community_id = public.mi_comunidad());
-- Solo el MasterUser nombra Directores (A-01). El MasterUser se crea con service_role.
create policy roles_alta on admin_roles for insert to authenticated
  with check (role = 'director' and public.es_master(community_id));
create policy roles_baja on admin_roles for delete to authenticated
  using (role = 'director' and public.es_master(community_id));

-- ── Equipos ─────────────────────────────────────────────────────────────────────
create policy equipos_lectura on teams for select to authenticated using (true);
create policy equipos_alta on teams for insert to authenticated with check (community_id = public.mi_comunidad());
create policy equipos_edicion on teams for update to authenticated using (public.es_staff_del_equipo(id));

create policy afiliacion_lectura on team_memberships for select to authenticated
  using (profile_id = auth.uid() or public.es_staff_del_equipo(team_id)
         or public.es_admin_comunidad((select community_id from teams where id = team_id))
         or (status = 'aprobada' and not public.es_menor(profile_id)));
create policy afiliacion_solicitud on team_memberships for insert to authenticated
  with check (profile_id = auth.uid() and status = 'pendiente');
create policy afiliacion_resolucion on team_memberships for update to authenticated
  using (public.es_staff_del_equipo(team_id))
  with check (public.es_staff_del_equipo(team_id) and resolved_by = auth.uid());

-- ── Torneos ─────────────────────────────────────────────────────────────────────
create policy torneos_lectura on tournaments for select to authenticated using (true);
create policy torneos_alta on tournaments for insert to authenticated with check (public.es_admin_comunidad(community_id));
create policy torneos_edicion on tournaments for update to authenticated using (public.es_admin_torneo(id));

create policy reglas_lectura on tournament_rules for select to authenticated using (true);
create policy reglas_escritura on tournament_rules for all to authenticated
  using (public.es_admin_torneo(tournament_id)) with check (public.es_admin_torneo(tournament_id));

create policy admins_torneo_lectura on tournament_admins for select to authenticated using (true);
create policy admins_torneo_alta on tournament_admins for insert to authenticated
  with check (public.es_admin_comunidad((select community_id from tournaments where id = tournament_id)));

create policy inscripcion_lectura on tournament_teams for select to authenticated using (true);
create policy inscripcion_escritura on tournament_teams for all to authenticated
  using (public.es_admin_torneo(tournament_id)) with check (public.es_admin_torneo(tournament_id));

create policy plantilla_lectura on tournament_rosters for select to authenticated using (public.puede_ver_perfil(profile_id));
create policy plantilla_escritura on tournament_rosters for all to authenticated
  using (public.es_admin_torneo((select tournament_id from tournament_teams where id = tournament_team_id))
         or public.es_staff_del_equipo((select team_id from tournament_teams where id = tournament_team_id)))
  with check (public.es_admin_torneo((select tournament_id from tournament_teams where id = tournament_team_id))
         or public.es_staff_del_equipo((select team_id from tournament_teams where id = tournament_team_id)));

-- ── Partido ─────────────────────────────────────────────────────────────────────
create policy partidos_lectura on matches for select to authenticated using (true);
create policy partidos_escritura on matches for all to authenticated
  using (public.es_admin_torneo(tournament_id) or public.es_oficial_de(id))
  with check (public.es_admin_torneo(tournament_id) or public.es_oficial_de(id));

create policy oficiales_lectura on match_officials for select to authenticated using (true);
create policy oficiales_escritura on match_officials for all to authenticated
  using (public.es_admin_torneo((select tournament_id from matches where id = match_id)))
  with check (public.es_admin_torneo((select tournament_id from matches where id = match_id)));

create policy alineacion_lectura on match_lineups for select to authenticated using (true);
create policy alineacion_escritura on match_lineups for all to authenticated
  using (public.es_staff_del_equipo((select tt.team_id from tournament_rosters r join tournament_teams tt on tt.id = r.tournament_team_id where r.id = roster_id)))
  with check (public.es_staff_del_equipo((select tt.team_id from tournament_rosters r join tournament_teams tt on tt.id = r.tournament_team_id where r.id = roster_id)));

-- Eventos: lectura para todos (marcador público); alta solo por oficiales del partido mientras está en vivo.
create policy eventos_lectura on match_events for select to authenticated using (true);
create policy eventos_alta on match_events for insert to authenticated
  with check (created_by = auth.uid() and public.es_oficial_de(match_id)
              and (select stage from matches where id = match_id) = 'live');
-- Sin update ni delete (RNF-13). Además, un trigger lo impide incluso con service_role:
create or replace function public.eventos_inmutables() returns trigger language plpgsql as $$
begin
  raise exception 'match_events es de solo inserción: registra un evento de anulación (RNF-13)';
end $$;
create trigger eventos_inmutables before update or delete on public.match_events
  for each row execute function public.eventos_inmutables();

create policy reportes_lectura on match_reports for select to authenticated
  using (kind in ('pre','post')
         or (kind = 'medical' and (public.es_medico() or public.es_admin_torneo((select tournament_id from matches where id = match_id))))
         or (kind = 'discipline' and (public.es_oficial_de(match_id) or public.es_admin_torneo((select tournament_id from matches where id = match_id)))));
create policy reportes_alta on match_reports for insert to authenticated
  with check (public.es_oficial_de(match_id) or public.es_admin_torneo((select tournament_id from matches where id = match_id)));

-- ── Interacción ─────────────────────────────────────────────────────────────────
create policy seguir_propio on follows for all to authenticated
  using (follower_id = auth.uid()) with check (follower_id = auth.uid());
create policy notificaciones_propias on notifications for select to authenticated using (profile_id = auth.uid());
create policy notificaciones_leidas on notifications for update to authenticated
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());
create policy posts_lectura on posts for select to authenticated using (true);
create policy posts_alta on posts for insert to authenticated
  with check (author_id = auth.uid() and public.es_admin_torneo(tournament_id));

grant select on public.standings to authenticated;
