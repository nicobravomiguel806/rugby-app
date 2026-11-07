-- C-01 · Seguridad del registro: `privacy_consents` (CP-162) y `community_id` inmutable para el usuario (CP-161, AT-18 a).
-- Casos de abuso C01-1a a C01-3 del contrato docs/historias/C-01.md §3.3: cada uno DEBE negar. Al final, los
-- controles positivos (deben permitir) para no aprobar una política que niega todo.
-- Formato TAP por NOTICE, igual que 10_. Es autosuficiente (datos propios, comunidades 4 y 5, usuarios …0018 a …0022)
-- y corre dentro de una transacción que se revierte: no deja datos y puede ejecutarse solo o incluido desde 10_.
\set ON_ERROR_STOP on
set client_min_messages = notice;
reset role;
begin;

-- ── Utilidades de prueba (las de 10_ y tres nuevas) ─────────────────────────────
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
-- C-01 · Como `tests.como`, pero con `app_metadata.provider` en los claims (lo firma Supabase Auth en el JWT real).
create or replace function tests.como_con_proveedor(usuario uuid, proveedor text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object(
    'sub', usuario, 'role', 'authenticated', 'app_metadata', json_build_object('provider', proveedor))::text, false);
$$;
-- C-01 · Error esperado cuyo mensaje contiene `patron` (distingue «lo negó el trigger» de «falló por otra cosa»).
create or replace function tests.lanza_con(sql text, patron text, nombre text) returns void language plpgsql as $$
begin
  execute sql;
  raise notice 'not ok - % (se esperaba un error y no hubo)', nombre;
exception when others then
  if position(patron in sqlerrm) > 0 then
    raise notice 'ok - % [%]', nombre, sqlerrm;
  else
    raise notice 'not ok - % (error distinto: %)', nombre, sqlerrm;
  end if;
end $$;
-- C-01 · Filas afectadas por una sentencia, o -1 si lanzó error (una negación puede ser 0 filas o error).
create or replace function tests.filas(sql text) returns integer language plpgsql as $$
declare n integer;
begin
  execute sql;
  get diagnostics n = row_count;
  return n;
exception when others then
  return -1;
end $$;
grant usage on schema tests to authenticated, anon;
grant execute on all functions in schema tests to authenticated, anon;

-- ── Datos (como superusuario) ───────────────────────────────────────────────────
-- 18 atacante (correo, adulto de la comunidad 4) · 19 Director de la comunidad 4 · 20 miembro adulto de la comunidad 4
-- 21 cuenta nueva de Google sin perfil · 22 víctima: adulto de la comunidad 5 (destino del atacante)
insert into auth.users (id) values
  ('00000000-0000-0000-0000-000000000018'), ('00000000-0000-0000-0000-000000000019'),
  ('00000000-0000-0000-0000-000000000020'), ('00000000-0000-0000-0000-000000000021'),
  ('00000000-0000-0000-0000-000000000022');
insert into communities (id, name) values
  ('c0000000-0000-0000-0000-000000000004', 'Rugby C-01'),
  ('c0000000-0000-0000-0000-000000000005', 'Liga destino C-01');
insert into profiles (id, community_id, full_name, birth_date) values
  ('00000000-0000-0000-0000-000000000018', 'c0000000-0000-0000-0000-000000000004', 'Atacante C01', date '1990-01-01'),
  ('00000000-0000-0000-0000-000000000019', 'c0000000-0000-0000-0000-000000000004', 'Director C01', date '1980-01-01'),
  ('00000000-0000-0000-0000-000000000020', 'c0000000-0000-0000-0000-000000000004', 'Miembro C01', date '1992-01-01'),
  ('00000000-0000-0000-0000-000000000022', 'c0000000-0000-0000-0000-000000000005', 'Victima C01', date '1991-01-01');
insert into admin_roles (profile_id, community_id, role) values
  ('00000000-0000-0000-0000-000000000019', 'c0000000-0000-0000-0000-000000000004', 'director');

-- ── CP-161 · AT-18 (a): community_id inmutable para el usuario ─────────────────
set role authenticated;
select tests.como_con_proveedor('00000000-0000-0000-0000-000000000018', 'email');
select tests.lanza_con($$update profiles set community_id = 'c0000000-0000-0000-0000-000000000005' where id = '00000000-0000-0000-0000-000000000018'$$,
                       'AT-18', 'C01-1a (CP-161) Un usuario no cambia el community_id de su propio perfil');
select tests.como_con_proveedor('00000000-0000-0000-0000-000000000019', 'email');
select tests.ok(tests.filas($$update profiles set community_id = 'c0000000-0000-0000-0000-000000000005' where id = '00000000-0000-0000-0000-000000000020'$$) <= 0,
                'C01-1b (CP-161) Un Director no cambia el community_id de un miembro (0 filas o error)');
select tests.como_con_proveedor('00000000-0000-0000-0000-000000000018', 'email');
select tests.ok((select count(*) from profiles where community_id = 'c0000000-0000-0000-0000-000000000005') = 0,
                'C01-1c (CP-161) El atacante sigue sin ver a los adultos de la comunidad destino');
reset role;
select tests.ok((select community_id from profiles where id = '00000000-0000-0000-0000-000000000018') = 'c0000000-0000-0000-0000-000000000004'
                and (select community_id from profiles where id = '00000000-0000-0000-0000-000000000020') = 'c0000000-0000-0000-0000-000000000004',
                'C01-1a/1b (CP-161) Los community_id no cambiaron');

-- ── CP-162 · Controles positivos de la RPC (deben permitir) ─────────────────────
set role authenticated;
select tests.como_con_proveedor('00000000-0000-0000-0000-000000000021', 'google');
select tests.ok(aceptar_aviso_de_privacidad('v0-borrador', '{notificaciones}'),
                'C01-P1 (CP-162) La RPC registra el aviso con {notificaciones} y devuelve true');
select tests.ok((select count(*) from privacy_consents) = 4
                and (select count(*) from privacy_consents where kind = 'aviso' and granted) = 1
                and (select count(*) from privacy_consents where kind = 'finalidad_secundaria') = 3
                and (select array_agg(purpose order by purpose) from privacy_consents where kind = 'finalidad_secundaria' and granted) = '{notificaciones}',
                'C01-P2 (CP-162) Quedan 4 filas: 1 aviso + 3 finalidades, solo notificaciones con granted = true');
select tests.ok((select bool_and(signup_method = 'google' and notice_version = 'v0-borrador'
                                 and user_id = '00000000-0000-0000-0000-000000000021' and accepted_at = now()) from privacy_consents),
                'C01-P3 (CP-162) Usuario, método (google) y fecha los pone el servidor');
select tests.ok(not aceptar_aviso_de_privacidad('v0-borrador', '{comunicaciones}') and (select count(*) from privacy_consents) = 4,
                'C01-P4 (CP-162) Reintentar devuelve false y no agrega filas (idempotente)');
select tests.como_con_proveedor('00000000-0000-0000-0000-000000000020', 'email');
select aceptar_aviso_de_privacidad('v0-borrador', '{notificaciones,estadisticas}');
select tests.ok((select array_agg(purpose order by purpose) from privacy_consents where kind = 'finalidad_secundaria' and granted) = '{notificaciones,estadisticas}'
                and (select not granted from privacy_consents where purpose = 'comunicaciones')
                and (select bool_and(signup_method = 'correo') from privacy_consents),
                'C01-P5 (CP-162) Con {notificaciones,estadisticas} esas dos quedan en true y comunicaciones en false (A-1); método correo');
select tests.como_con_proveedor('00000000-0000-0000-0000-000000000019', 'email');
select aceptar_aviso_de_privacidad('v0-borrador', '{}');
select tests.ok((select count(*) from privacy_consents where kind = 'finalidad_secundaria' and not granted) = 3,
                'C01-P6 (CP-162) Con {} las tres finalidades quedan en false (también se guarda la negativa)');
select tests.como_con_proveedor('00000000-0000-0000-0000-000000000021', 'google');
select tests.ok((select count(*) from privacy_consents) = 4, 'C01-P7 (CP-162) El usuario lee sus 4 filas');
select tests.como_con_proveedor('00000000-0000-0000-0000-000000000018', 'email');
update profiles set full_name = 'Atacante renombrado' where id = '00000000-0000-0000-0000-000000000018';
reset role;
select tests.ok((select full_name from profiles where id = '00000000-0000-0000-0000-000000000018') = 'Atacante renombrado',
                'C01-P8 (CP-161) El usuario sí cambia su full_name');

-- ── CP-162 · Casos de abuso de privacy_consents (deben negar) ───────────────────
set role anon;
select tests.lanza_con($$select * from privacy_consents$$, 'permission denied', 'C01-2a (CP-162) anon no lee privacy_consents');
select tests.lanza_con($$insert into privacy_consents (user_id, notice_version, kind, granted, signup_method) values ('00000000-0000-0000-0000-000000000022','v0-borrador','aviso',true,'correo')$$,
                       'permission denied', 'C01-2a (CP-162) anon no inserta en privacy_consents');
select tests.lanza_con($$select aceptar_aviso_de_privacidad('v0-borrador')$$, 'permission denied', 'C01-2a (CP-162) anon no llama a la RPC');
reset role;

set role authenticated;
select tests.como_con_proveedor('00000000-0000-0000-0000-000000000018', 'email');
select tests.lanza($$insert into privacy_consents (user_id, notice_version, kind, granted) values ('00000000-0000-0000-0000-000000000022','v0-borrador','aviso',true)$$,
                   'C01-2b (CP-162) No se inserta un consentimiento con el user_id de otro usuario');
insert into privacy_consents (notice_version, kind, purpose, granted, accepted_at, signup_method)
values ('v0-borrador', 'finalidad_secundaria', 'notificaciones', true, '2020-01-01', 'google');
select tests.ok((select accepted_at = now() from privacy_consents where purpose = 'notificaciones'),
                'C01-2c (CP-162) accepted_at del cliente se ignora: queda now()');
select tests.ok((select signup_method = 'correo' from privacy_consents where purpose = 'notificaciones'),
                'C01-2d (CP-162) Con provider = email, signup_method = google del cliente queda correo');
select tests.como_con_proveedor('00000000-0000-0000-0000-000000000018', 'apple');
select tests.lanza_con($$insert into privacy_consents (notice_version, kind, purpose, granted, signup_method) values ('v0-borrador','finalidad_secundaria','estadisticas',true,'correo')$$,
                       'metodo de alta', 'C01-2d (CP-162) Con provider = apple el alta se niega (SP-07)');
select tests.como('00000000-0000-0000-0000-000000000018');
select tests.lanza_con($$insert into privacy_consents (notice_version, kind, purpose, granted, signup_method) values ('v0-borrador','finalidad_secundaria','estadisticas',true,'correo')$$,
                       'metodo de alta', 'C01-2d (CP-162) Sin claim de provider el alta se niega');
select tests.como_con_proveedor('00000000-0000-0000-0000-000000000018', 'email');
select tests.lanza_con($$insert into privacy_consents (notice_version, kind, granted, signup_method) values ('v9','aviso',true,'correo')$$,
                       'version_desactualizada', 'C01-2e (CP-162) insert con notice_version = v9 → version_desactualizada');
select tests.lanza_con($$select aceptar_aviso_de_privacidad('v9', '{}')$$,
                       'version_desactualizada', 'C01-2e (CP-162) RPC con v9 → version_desactualizada');
select tests.lanza($$insert into privacy_consents (notice_version, kind, granted) values ('v0-borrador','aviso',false)$$,
                   'C01-2h (CP-162) check: un aviso con granted = false se rechaza');
select tests.lanza($$insert into privacy_consents (notice_version, kind, purpose, granted) values ('v0-borrador','aviso','estadisticas',true)$$,
                   'C01-2h (CP-162) check: un aviso con purpose se rechaza');
select tests.lanza($$insert into privacy_consents (notice_version, kind, granted) values ('v0-borrador','finalidad_secundaria',true)$$,
                   'C01-2h (CP-162) check: una finalidad sin purpose se rechaza');

select tests.como_con_proveedor('00000000-0000-0000-0000-000000000021', 'google');
select tests.lanza($$update privacy_consents set granted = false where purpose = 'notificaciones'$$,
                   'C01-2f (CP-162) update de una fila propia se niega');
select tests.lanza_con($$delete from privacy_consents$$, 'permission denied', 'C01-2f (CP-162) delete de una fila propia se niega');
select tests.ok((select count(*) from privacy_consents) = 4
                and (select granted from privacy_consents where purpose = 'notificaciones'),
                'C01-2f (CP-162) Tras el update y el delete las filas siguen iguales');

select tests.como_con_proveedor('00000000-0000-0000-0000-000000000019', 'email');
select tests.ok((select count(*) from privacy_consents where user_id <> '00000000-0000-0000-0000-000000000019') = 0
                and (select count(*) from privacy_consents where user_id = '00000000-0000-0000-0000-000000000020') = 0,
                'C01-2g (CP-162) Un Director no lee los consentimientos de un miembro de su comunidad (ni ajenos)');
reset role;
select tests.ok((select count(*) from privacy_consents where user_id = '00000000-0000-0000-0000-000000000022') = 0,
                'C01-2b (CP-162) La víctima sigue con 0 filas');

-- service_role: en Supabase tiene todos los privilegios; el stub local no, así que se le dan dentro de esta
-- transacción (se revierte) para probar que el trigger aplica aunque haya privilegios.
grant select, update on public.privacy_consents to service_role;
grant select, update on public.profiles to service_role;
grant usage on schema tests to service_role;
grant execute on all functions in schema tests to service_role;
set role service_role;
select tests.lanza_con($$update privacy_consents set accepted_at = '2020-01-01'$$, 'solo inserción',
                       'C01-2i (CP-162) service_role tampoco edita un consentimiento (trigger)');
update profiles set community_id = 'c0000000-0000-0000-0000-000000000005' where id = '00000000-0000-0000-0000-000000000020';
reset role;
select tests.ok((select community_id from profiles where id = '00000000-0000-0000-0000-000000000020') = 'c0000000-0000-0000-0000-000000000005',
                'C01-P9 (CP-161) service_role sí cambia un community_id (control positivo)');

-- ── C01-3 (CP-150 / CP-151a) ────────────────────────────────────────────────────
select tests.ok((select count(*) from pg_tables where schemaname = 'public') = 23
                and (select bool_and(rowsecurity) from pg_tables where schemaname = 'public'),
                'C01-3 (CP-150) 23 tablas en public, todas con RLS activa (incluida privacy_consents)');
select tests.ok((select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                 where n.nspname = 'public' and p.prosecdef) = 0,
                'C01-3 (CP-151a) Sigue sin haber funciones SECURITY DEFINER en public (la RPC es security invoker)');

rollback;
