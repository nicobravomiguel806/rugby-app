-- SP-03 / SP-02 · Pruebas de seguridad (RLS) y sincronización idempotente.
-- Formato TAP por NOTICE: "ok - …" / "not ok - …". Casos CP-140 a CP-152 del Plan de Pruebas.
\set ON_ERROR_STOP on
set client_min_messages = notice;

-- ── Utilidades de prueba ────────────────────────────────────────────────────────
create schema if not exists tests;
create or replace function tests.ok(cond boolean, nombre text) returns void language plpgsql as $$
begin
  if coalesce(cond, false) then raise notice 'ok - %', nombre; else raise notice 'not ok - %', nombre; end if;
end $$;
create or replace function tests.lanza(sql text, nombre text) returns void language plpgsql as $$
begin
  execute sql;
  raise notice 'not ok - % (se esperaba un error y no hubo)', nombre;
exception when others then
  raise notice 'ok - % [%]', nombre, sqlerrm;
end $$;
create or replace function tests.como(usuario uuid) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', usuario, 'role', 'authenticated')::text, false);
$$;
grant usage on schema tests to authenticated, anon;
grant execute on all functions in schema tests to authenticated, anon;

-- ── Datos de prueba (como superusuario, sin RLS) ────────────────────────────────
-- 01 master · 02 director · 03 admin torneo · 04 entrenador · 05 médico · 06 jugador adulto
-- 07 jugador menor · 08 tutor · 09 fan · 10 de otra comunidad · 11 árbitro
insert into auth.users (id) select ('00000000-0000-0000-0000-0000000000' || lpad(i::text, 2, '0'))::uuid from generate_series(1, 11) i;
insert into communities (id, name) values
  ('c0000000-0000-0000-0000-000000000001', 'Rugby Querétaro'),
  ('c0000000-0000-0000-0000-000000000002', 'Otra comunidad');
insert into profiles (id, community_id, full_name, birth_date)
select ('00000000-0000-0000-0000-0000000000' || lpad(i::text, 2, '0'))::uuid,
       case when i = 10 then 'c0000000-0000-0000-0000-000000000002'::uuid else 'c0000000-0000-0000-0000-000000000001'::uuid end,
       'Usuario ' || i,
       case when i = 7 then current_date - interval '13 years' else date '1995-05-10' end
from generate_series(1, 11) i;
insert into profile_types values ('00000000-0000-0000-0000-000000000005', 'medico'),
                                 ('00000000-0000-0000-0000-000000000004', 'entrenador');
insert into admin_roles (profile_id, community_id, role) values
  ('00000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'masteruser'),
  ('00000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000001', 'director');
insert into teams (id, community_id, name) values
  ('a0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'Lobos'),
  ('a0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000001', 'Toros');
insert into team_memberships (team_id, profile_id, role, status) values
  ('a0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000004', 'entrenador', 'aprobada'),
  ('a0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000005', 'medico', 'aprobada'),
  ('a0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000006', 'jugador', 'aprobada'),
  ('a0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000007', 'jugador', 'aprobada');
insert into guardianships values ('00000000-0000-0000-0000-000000000008', '00000000-0000-0000-0000-000000000007', 'aprobada', now());
insert into medical_records (player_id, medic_id, fitness_status, injury) values
  ('00000000-0000-0000-0000-000000000007', '00000000-0000-0000-0000-000000000005', 'no_apto', 'Esguince de tobillo'),
  ('00000000-0000-0000-0000-000000000006', '00000000-0000-0000-0000-000000000005', 'apto', null);
insert into tournaments (id, community_id, name, modality) values
  ('b0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'Liga Bajío', '15');
insert into tournament_admins values ('b0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000003');
insert into tournament_teams (id, tournament_id, team_id) values
  ('d0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001'),
  ('d0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000002');
insert into matches (id, tournament_id, home_tt_id, away_tt_id, stage) values
  ('e0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000002', 'live'),
  ('e0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000002', 'pre');
insert into match_officials values
  ('e0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000011', 'arbitro'),
  ('e0000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000011', 'arbitro');

-- ── Pruebas ─────────────────────────────────────────────────────────────────────
set role authenticated;

-- CP-140 · Perfiles de menores
select tests.como('00000000-0000-0000-0000-000000000009');
select tests.ok((select count(*) from profiles where id = '00000000-0000-0000-0000-000000000007') = 0, 'CP-140a Un fan no ve el perfil de un menor');
select tests.ok((select count(*) from profiles where id = '00000000-0000-0000-0000-000000000006') = 1, 'CP-140b Un fan sí ve el perfil de un adulto de su comunidad');
select tests.como('00000000-0000-0000-0000-000000000008');
select tests.ok((select count(*) from profiles where id = '00000000-0000-0000-0000-000000000007') = 1, 'CP-140c El tutor ve el perfil del menor');
select tests.como('00000000-0000-0000-0000-000000000004');
select tests.ok((select count(*) from profiles where id = '00000000-0000-0000-0000-000000000007') = 1, 'CP-140d El entrenador del equipo ve al menor');
select tests.como('00000000-0000-0000-0000-000000000010');
select tests.ok((select count(*) from profiles where id = '00000000-0000-0000-0000-000000000006') = 0, 'CP-140e Un usuario de otra comunidad no ve perfiles ajenos');

-- CP-141 · Lectura de datos médicos (RNF-04)
select tests.como('00000000-0000-0000-0000-000000000006');
select tests.ok((select count(*) from medical_records) = 1, 'CP-141a El jugador solo ve su propio registro médico');
select tests.como('00000000-0000-0000-0000-000000000008');
select tests.ok((select count(*) from medical_records where player_id = '00000000-0000-0000-0000-000000000007') = 1, 'CP-141b El tutor ve el registro médico del menor');
select tests.como('00000000-0000-0000-0000-000000000004');
select tests.ok((select count(*) from medical_records) = 0, 'CP-141c El entrenador NO ve datos médicos');
select tests.como('00000000-0000-0000-0000-000000000009');
select tests.ok((select count(*) from medical_records) = 0, 'CP-141d Un fan NO ve datos médicos');
select tests.como('00000000-0000-0000-0000-000000000005');
select tests.ok((select count(*) from medical_records) = 2, 'CP-141e El médico del equipo ve los registros de sus jugadores');

-- CP-142 · Alta de datos médicos
select tests.como('00000000-0000-0000-0000-000000000004');
select tests.lanza($$insert into medical_records (player_id, medic_id, fitness_status) values ('00000000-0000-0000-0000-000000000006','00000000-0000-0000-0000-000000000004','apto')$$,
                   'CP-142a Un entrenador no puede registrar datos médicos');
select tests.como('00000000-0000-0000-0000-000000000005');
insert into medical_records (player_id, medic_id, fitness_status) values ('00000000-0000-0000-0000-000000000006','00000000-0000-0000-0000-000000000005','apto_con_restricciones');
select tests.ok(true, 'CP-142b El médico registra datos de un jugador de su equipo');
select tests.lanza($$insert into medical_records (player_id, medic_id, fitness_status) values ('00000000-0000-0000-0000-000000000009','00000000-0000-0000-0000-000000000005','apto')$$,
                   'CP-142c El médico no registra datos de alguien fuera de su equipo');

-- CP-143 · Escalada de privilegios
select tests.como('00000000-0000-0000-0000-000000000009');
select tests.lanza($$insert into profile_types values ('00000000-0000-0000-0000-000000000009','medico')$$,
                   'CP-143a Nadie se autoasigna el tipo médico');
select tests.como('00000000-0000-0000-0000-000000000002');
select tests.lanza($$insert into admin_roles (profile_id, community_id, role) values ('00000000-0000-0000-0000-000000000009','c0000000-0000-0000-0000-000000000001','director')$$,
                   'CP-143b Un Director no puede nombrar Directores');
select tests.lanza($$insert into admin_roles (profile_id, community_id, role) values ('00000000-0000-0000-0000-000000000002','c0000000-0000-0000-0000-000000000001','masteruser')$$,
                   'CP-143c Nadie se convierte en MasterUser desde la app');
select tests.como('00000000-0000-0000-0000-000000000001');
insert into admin_roles (profile_id, community_id, role) values ('00000000-0000-0000-0000-000000000003','c0000000-0000-0000-0000-000000000001','director');
select tests.ok(true, 'CP-143d El MasterUser nombra un Director (A-01)');

-- CP-144 · Torneos por comunidad
select tests.como('00000000-0000-0000-0000-000000000002');
insert into tournaments (community_id, name, modality) values ('c0000000-0000-0000-0000-000000000001', 'Copa Seven', '7');
select tests.ok(true, 'CP-144a El Director crea un torneo en su comunidad');
select tests.lanza($$insert into tournaments (community_id, name, modality) values ('c0000000-0000-0000-0000-000000000002','Intruso','15')$$,
                   'CP-144b El Director no crea torneos en otra comunidad');
select tests.como('00000000-0000-0000-0000-000000000009');
select tests.lanza($$insert into tournaments (community_id, name, modality) values ('c0000000-0000-0000-0000-000000000001','Fan','15')$$,
                   'CP-144c Un fan no crea torneos');

-- CP-145 · Tutela de menores (C-05)
select tests.como('00000000-0000-0000-0000-000000000009');
select tests.lanza($$insert into guardianships values ('00000000-0000-0000-0000-000000000009','00000000-0000-0000-0000-000000000006','aprobada', now())$$,
                   'CP-145a Nadie se registra como tutor ya aprobado');
insert into guardianships (guardian_id, minor_id) values ('00000000-0000-0000-0000-000000000009','00000000-0000-0000-0000-000000000007');
update guardianships set status = 'aprobada' where guardian_id = '00000000-0000-0000-0000-000000000009';
select tests.como('00000000-0000-0000-0000-000000000002');
select tests.ok((select status from guardianships where guardian_id = '00000000-0000-0000-0000-000000000009') = 'pendiente',
                'CP-145b El solicitante no puede aprobar su propia tutela');
update guardianships set status = 'aprobada', consent_at = now() where guardian_id = '00000000-0000-0000-0000-000000000009';
select tests.ok((select status from guardianships where guardian_id = '00000000-0000-0000-0000-000000000009') = 'aprobada',
                'CP-145c El Director valida la tutela');

-- CP-146 · Sincronización idempotente (SP-02)
select tests.como('00000000-0000-0000-0000-000000000011');
create temp table lote as select $j$[
 {"id":"f0000000-0000-0000-0000-000000000001","match_id":"e0000000-0000-0000-0000-000000000001","type":"ensayo","team_side":"local","minute":12,"points":5,"client_ts":"2026-10-28T10:12:00Z","device_seq":1},
 {"id":"f0000000-0000-0000-0000-000000000002","match_id":"e0000000-0000-0000-0000-000000000001","type":"conversion","team_side":"local","minute":13,"points":2,"client_ts":"2026-10-28T10:13:00Z","device_seq":2},
 {"id":"f0000000-0000-0000-0000-000000000003","match_id":"e0000000-0000-0000-0000-000000000001","type":"penal","team_side":"visita","minute":20,"points":3,"client_ts":"2026-10-28T10:20:00Z","device_seq":3,
  "created_by":"00000000-0000-0000-0000-000000000009"}
]$j$::jsonb as j;
select tests.ok((select count(*) from sync_match_events((select j from lote))) = 3, 'CP-146a El árbitro sincroniza 3 eventos y recibe 3 confirmaciones');
select tests.ok((select count(*) from sync_match_events((select j from lote))) = 3, 'CP-146b Reenviar el mismo lote devuelve las mismas 3 confirmaciones');
select tests.ok((select count(*) from match_events) = 3, 'CP-146c Reenviar no duplica eventos');
select tests.ok((select bool_and(created_by = '00000000-0000-0000-0000-000000000011') from match_events), 'CP-146d El autor lo asigna el servidor aunque el cliente mande otro');
select tests.ok((select bool_and(server_ts is not null and client_ts is not null) from match_events), 'CP-146e Cada evento guarda hora del dispositivo y del servidor (RNF-13)');

-- CP-147 · Quién puede registrar eventos
select tests.lanza($$select sync_match_events('[{"id":"f0000000-0000-0000-0000-000000000009","match_id":"e0000000-0000-0000-0000-000000000002","type":"ensayo","team_side":"local","minute":1,"client_ts":"2026-10-28T10:00:00Z","device_seq":9}]')$$,
                   'CP-147a No se registran eventos en un partido que no está en vivo');
select tests.como('00000000-0000-0000-0000-000000000009');
select tests.lanza($$select sync_match_events('[{"id":"f0000000-0000-0000-0000-000000000008","match_id":"e0000000-0000-0000-0000-000000000001","type":"ensayo","team_side":"local","minute":1,"client_ts":"2026-10-28T10:00:00Z","device_seq":1}]')$$,
                   'CP-147b Un fan no puede registrar eventos (alterar marcador)');
select tests.lanza($$select sync_match_events((select jsonb_agg(x) from generate_series(1,201) x))$$,
                   'CP-147c Se rechazan lotes de más de 200 eventos');

-- CP-148 · Eventos inmutables (RNF-13)
select tests.como('00000000-0000-0000-0000-000000000011');
update match_events set points = 50;
delete from match_events;
select tests.ok((select sum(points) from match_events) = 10, 'CP-148a Un oficial no puede modificar ni borrar eventos');
reset role;
select tests.lanza($$update match_events set points = 50$$, 'CP-148b Ni siquiera un rol privilegiado puede modificar eventos');

-- CP-149 · Acceso anónimo
set role anon;
select tests.lanza($$select * from profiles$$, 'CP-149 Sin sesión no se lee ninguna tabla');
reset role;

-- CP-150 · Todas las tablas tienen RLS activa
select tests.ok((select bool_and(rowsecurity) from pg_tables where schemaname = 'public'), 'CP-150 Las 23 tablas tienen RLS activa');
select tests.ok((select count(*) from pg_tables where schemaname = 'public') = 23, 'CP-150b El esquema tiene las 23 tablas (22 del MER + privacy_consents, C-01)');

-- CP-151 · Las funciones de permisos no están expuestas en la API (linter de Supabase, AT-01)
select tests.ok((select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                 where n.nspname = 'public' and p.prosecdef) = 0, 'CP-151a Ninguna función SECURITY DEFINER queda en el esquema público');
set role anon;
select tests.lanza($$select privado.es_menor('00000000-0000-0000-0000-000000000007')$$, 'CP-151b Sin sesión no se puede consultar si un perfil es menor');
reset role;

-- SP-04 · Usuario autenticado sin perfil (§3.3 caso de abuso 1). run-db-tests.sh solo ejecuta este archivo, así que se incluye aquí.
\ir 20_usuario_sin_perfil.test.sql

-- C-01 · privacy_consents y community_id inmutable (CP-161, CP-162). Mismo motivo: el runner solo ejecuta este archivo.
\ir 30_registro.test.sql

-- C-01 · Pruebas del agente de seguridad (ronda 1): bypasses de AT-18 (a) y de privacy_consents. Mismo motivo que arriba.
\ir 40_seguridad_registro.test.sql
