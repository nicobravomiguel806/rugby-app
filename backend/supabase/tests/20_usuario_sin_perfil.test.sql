-- SP-04 · Seguridad: un usuario autenticado SIN fila en `profiles` (el caso de toda cuenta nueva de Google,
-- porque el SPIKE no crea perfiles) no ve menores ajenos ni `medical_records` (§3.3 caso de abuso 1, AT-10/AT-11,
-- reglas de docs/domain-model.md §1). También prueba los caminos permitidos para no aprobar una política que niega todo.
-- Formato TAP por NOTICE, igual que 10_rls_y_sync.test.sql. Es autosuficiente (datos propios, comunidad 3) y corre
-- dentro de una transacción que se revierte: no deja datos y puede ejecutarse solo o incluido desde 10_.
\set ON_ERROR_STOP on
set client_min_messages = notice;
reset role;
begin;

-- ── Utilidades de prueba (las mismas de 10_) ────────────────────────────────────
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

-- ── Datos (como superusuario) ───────────────────────────────────────────────────
-- 12 sin perfil (cuenta nueva de Google) · 13 jugador adulto · 14 jugador menor · 15 médico · 16 tutor de 14
-- 17 otra cuenta sin perfil (víctima de suplantación)
insert into auth.users (id) values
  ('00000000-0000-0000-0000-000000000012'), ('00000000-0000-0000-0000-000000000013'),
  ('00000000-0000-0000-0000-000000000014'), ('00000000-0000-0000-0000-000000000015'),
  ('00000000-0000-0000-0000-000000000016'), ('00000000-0000-0000-0000-000000000017');
insert into communities (id, name) values ('c0000000-0000-0000-0000-000000000003', 'Rugby SP-04');
insert into profiles (id, community_id, full_name, birth_date) values
  ('00000000-0000-0000-0000-000000000013', 'c0000000-0000-0000-0000-000000000003', 'Adulto SP04', date '1990-01-01'),
  ('00000000-0000-0000-0000-000000000014', 'c0000000-0000-0000-0000-000000000003', 'Menor SP04', current_date - interval '12 years'),
  ('00000000-0000-0000-0000-000000000015', 'c0000000-0000-0000-0000-000000000003', 'Medico SP04', date '1980-01-01'),
  ('00000000-0000-0000-0000-000000000016', 'c0000000-0000-0000-0000-000000000003', 'Tutor SP04', date '1975-01-01');
insert into profile_types values ('00000000-0000-0000-0000-000000000015', 'medico');
insert into player_details (profile_id, position) values ('00000000-0000-0000-0000-000000000014', 'medio scrum');
insert into teams (id, community_id, name) values ('a0000000-0000-0000-0000-000000000003', 'c0000000-0000-0000-0000-000000000003', 'Halcones');
insert into team_memberships (team_id, profile_id, role, status) values
  ('a0000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000013', 'jugador', 'aprobada'),
  ('a0000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000014', 'jugador', 'aprobada'),
  ('a0000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000015', 'medico', 'aprobada');
insert into guardianships values ('00000000-0000-0000-0000-000000000016', '00000000-0000-0000-0000-000000000014', 'aprobada', now());
insert into medical_records (player_id, medic_id, fitness_status, injury) values
  ('00000000-0000-0000-0000-000000000014', '00000000-0000-0000-0000-000000000015', 'no_apto', 'Conmoción'),
  ('00000000-0000-0000-0000-000000000013', '00000000-0000-0000-0000-000000000015', 'apto', null);

-- ── Usuario autenticado sin perfil: lecturas que se niegan (❌) ─────────────────
set role authenticated;
select tests.como('00000000-0000-0000-0000-000000000012');
select tests.ok((select count(*) from profiles where id = '00000000-0000-0000-0000-000000000014') = 0,
                'SP04-1a Un usuario sin perfil no ve el perfil de un menor ajeno');
select tests.ok((select count(*) from profiles where public.profiles.birth_date > current_date - interval '18 years') = 0,
                'SP04-1b Un usuario sin perfil no ve ningún menor de ninguna comunidad');
select tests.ok((select count(*) from profiles) = 0,
                'SP04-1c Un usuario sin perfil no ve perfiles (no pertenece a ninguna comunidad)');
select tests.ok((select count(*) from medical_records) = 0,
                'SP04-1d Un usuario sin perfil no ve ningún registro médico (RNF-04)');
select tests.ok((select count(*) from player_details where profile_id = '00000000-0000-0000-0000-000000000014') = 0,
                'SP04-1e Un usuario sin perfil no ve los datos de jugador de un menor');
select tests.ok((select count(*) from team_memberships where profile_id = '00000000-0000-0000-0000-000000000014') = 0,
                'SP04-1f Un usuario sin perfil no ve la afiliación de un menor a su equipo');
select tests.ok((select count(*) from guardianships) = 0,
                'SP04-1g Un usuario sin perfil no ve tutelas');
select tests.ok((select count(*) from profile_types) = 0,
                'SP04-1h Un usuario sin perfil no ve los tipos de perfil (quién es médico)');
select tests.ok((select count(*) from admin_roles) = 0,
                'SP04-1i Un usuario sin perfil no ve los roles de administración');

-- ── Usuario autenticado sin perfil: escrituras que se niegan (❌) ───────────────
select tests.lanza($$insert into medical_records (player_id, medic_id, fitness_status) values ('00000000-0000-0000-0000-000000000014','00000000-0000-0000-0000-000000000015','apto')$$,
                   'SP04-2a Un usuario sin perfil no registra datos médicos a nombre del médico');
select tests.lanza($$insert into profiles (id, community_id, full_name, birth_date) values ('00000000-0000-0000-0000-000000000017','c0000000-0000-0000-0000-000000000003','Suplantado','1990-01-01')$$,
                   'SP04-2b Un usuario sin perfil no crea el perfil de otra cuenta (autoría por auth.uid())');
select tests.lanza($$insert into guardianships values ('00000000-0000-0000-0000-000000000013','00000000-0000-0000-0000-000000000014','aprobada', now())$$,
                   'SP04-2c Un usuario sin perfil no registra una tutela aprobada sobre un menor');
select tests.lanza($$insert into profile_types values ('00000000-0000-0000-0000-000000000013','medico')$$,
                   'SP04-2d Un usuario sin perfil no otorga el tipo médico a otro perfil');
update profiles set full_name = 'Alterado' where id = '00000000-0000-0000-0000-000000000014';
update medical_records set fitness_status = 'apto' where player_id = '00000000-0000-0000-0000-000000000014';
delete from medical_records;
reset role;
select tests.ok((select full_name from profiles where id = '00000000-0000-0000-0000-000000000014') = 'Menor SP04',
                'SP04-2e Un usuario sin perfil no modifica el perfil de un menor');
select tests.ok((select count(*) from medical_records where player_id = '00000000-0000-0000-0000-000000000014' and fitness_status = 'no_apto') = 1
                and (select count(*) from medical_records where player_id in ('00000000-0000-0000-0000-000000000013','00000000-0000-0000-0000-000000000014')) = 2,
                'SP04-2f Un usuario sin perfil no modifica ni borra registros médicos');

-- ── Sin sesión (anon) tampoco llega a los datos médicos ─────────────────────────
set role anon;
select tests.lanza($$select * from medical_records$$, 'SP04-3a Sin sesión no se leen registros médicos');
reset role;

-- ── Caminos permitidos (✅): las políticas no niegan todo ────────────────────────
set role authenticated;
select tests.como('00000000-0000-0000-0000-000000000012');
select tests.ok((select count(*) from communities where id = 'c0000000-0000-0000-0000-000000000003') = 1,
                'SP04-4a Un usuario sin perfil sí ve las comunidades (las ligas son datos deportivos de lectura nacional, P-2)');
select tests.ok((select count(*) from teams where id = 'a0000000-0000-0000-0000-000000000003') = 1,
                'SP04-4b Un usuario sin perfil sí ve los equipos (lectura pública)');
select tests.como('00000000-0000-0000-0000-000000000016');
select tests.ok((select count(*) from profiles where id = '00000000-0000-0000-0000-000000000014') = 1
                and (select count(*) from medical_records where player_id = '00000000-0000-0000-0000-000000000014') = 1,
                'SP04-4c El tutor sí ve el perfil y el registro médico del menor (control positivo)');
select tests.como('00000000-0000-0000-0000-000000000012');
insert into profiles (id, community_id, full_name, birth_date)
values ('00000000-0000-0000-0000-000000000012', 'c0000000-0000-0000-0000-000000000003', 'Nuevo Google', date '1992-03-03');
select tests.ok(true, 'SP04-4d Un usuario sin perfil crea su propio perfil (id = auth.uid())');

-- Recién dado de alta (adulto, sin rol ni tutela): sigue sin ver al menor ni datos médicos
select tests.ok((select count(*) from profiles where id = '00000000-0000-0000-0000-000000000014') = 0,
                'SP04-5a Recién registrado en la comunidad sigue sin ver al menor');
select tests.ok((select count(*) from medical_records) = 0,
                'SP04-5b Recién registrado sigue sin ver registros médicos');
select tests.ok((select count(*) from profiles where id = '00000000-0000-0000-0000-000000000013') = 1,
                'SP04-5c Recién registrado ve a los adultos de su comunidad (regla de visibilidad, control positivo)');
reset role;

rollback;
