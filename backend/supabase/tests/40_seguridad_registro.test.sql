-- C-01 · Pruebas del agente de seguridad (ronda 1). Complementan 30_registro.test.sql con los intentos de bypass que
-- no cubre: otras formas de escribir `community_id` (upsert, varias columnas, fila, MERGE, borrar y volver a crear),
-- desactivar triggers, `signup_method` desde user_metadata, upsert/truncate sobre privacy_consents, la baja en cascada,
-- service_role sin JWT y las propiedades de las funciones nuevas (security invoker, search_path, sin SQL dinámico).
-- Cada caso C01-Sn DEBE negar; los C01-SPn son controles positivos (deben permitir).
-- Autosuficiente: comunidades 6 y 7, usuarios …0023 a …0027; corre en una transacción que se revierte.
\set ON_ERROR_STOP on
set client_min_messages = notice;
reset role;
begin;

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
create or replace function tests.filas(sql text) returns integer language plpgsql as $$
declare n integer;
begin
  execute sql;
  get diagnostics n = row_count;
  return n;
exception when others then
  return -1;
end $$;
create or replace function tests.con_claims(claims jsonb) returns void language sql as $$
  select set_config('request.jwt.claims', claims::text, false);
$$;
create or replace function tests.como_con_proveedor(usuario uuid, proveedor text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object(
    'sub', usuario, 'role', 'authenticated', 'app_metadata', json_build_object('provider', proveedor))::text, false);
$$;
grant usage on schema tests to authenticated, anon;
grant execute on all functions in schema tests to authenticated, anon;

-- ── Datos (como superusuario) ───────────────────────────────────────────────────
-- 23 atacante (adulto, comunidad 6) · 24 Director de la comunidad 6 · 25 cuenta de Google sin perfil (baja)
-- 26 cuenta de correo sin perfil · 27 adulto de la comunidad 7 (destino)
insert into auth.users (id) values
  ('00000000-0000-0000-0000-000000000023'), ('00000000-0000-0000-0000-000000000024'),
  ('00000000-0000-0000-0000-000000000025'), ('00000000-0000-0000-0000-000000000026'),
  ('00000000-0000-0000-0000-000000000027');
insert into communities (id, name) values
  ('c0000000-0000-0000-0000-000000000006', 'Seguridad C-01'),
  ('c0000000-0000-0000-0000-000000000007', 'Destino seguridad C-01');
insert into profiles (id, community_id, full_name, birth_date) values
  ('00000000-0000-0000-0000-000000000023', 'c0000000-0000-0000-0000-000000000006', 'Atacante S', date '1990-01-01'),
  ('00000000-0000-0000-0000-000000000024', 'c0000000-0000-0000-0000-000000000006', 'Director S', date '1980-01-01'),
  ('00000000-0000-0000-0000-000000000027', 'c0000000-0000-0000-0000-000000000007', 'Destino S', date '1985-01-01');
insert into admin_roles (profile_id, community_id, role) values
  ('00000000-0000-0000-0000-000000000024', 'c0000000-0000-0000-0000-000000000006', 'director');

-- ── AT-18 (a): otras formas de cambiar community_id ─────────────────────────────
set role authenticated;
select tests.como_con_proveedor('00000000-0000-0000-0000-000000000023', 'email');
select tests.lanza_con($$insert into profiles (id, community_id, full_name, birth_date)
                         values ('00000000-0000-0000-0000-000000000023', 'c0000000-0000-0000-0000-000000000007', 'Atacante S', date '1990-01-01')
                         on conflict (id) do update set community_id = excluded.community_id$$,
                       'AT-18', 'C01-S1 (CP-161) Upsert (on conflict do update) no cambia el community_id propio');
select tests.lanza_con($$update profiles set full_name = 'Nombre nuevo S', community_id = 'c0000000-0000-0000-0000-000000000007'
                         where id = '00000000-0000-0000-0000-000000000023'$$,
                       'AT-18', 'C01-S2 (CP-161) Update de varias columnas (full_name + community_id) se niega completo');
select tests.lanza_con($$update profiles set (full_name, community_id) = ('Nombre fila S', 'c0000000-0000-0000-0000-000000000007')
                         where id = '00000000-0000-0000-0000-000000000023'$$,
                       'AT-18', 'C01-S3 (CP-161) Update con constructor de fila se niega');
select tests.lanza_con($$merge into profiles p
                         using (select '00000000-0000-0000-0000-000000000023'::uuid as id) s on p.id = s.id
                         when matched then update set community_id = 'c0000000-0000-0000-0000-000000000007'$$,
                       'AT-18', 'C01-S4 (CP-161) MERGE … update set community_id se niega');
select tests.ok(tests.filas($$delete from profiles where id = '00000000-0000-0000-0000-000000000023'$$) <= 0,
                'C01-S5 (CP-161) El usuario no borra su perfil (para volver a crearlo en otra comunidad): 0 filas o error');
select tests.lanza($$set session_replication_role = replica$$,
                   'C01-S6 (CP-161) authenticated no desactiva los triggers con session_replication_role');
select tests.lanza($$alter table profiles disable trigger perfiles_comunidad_inmutable$$,
                   'C01-S7 (CP-161) authenticated no desactiva el trigger perfiles_comunidad_inmutable');
select tests.lanza($$alter table privacy_consents disable trigger consentimientos_inmutables$$,
                   'C01-S7 (CP-162) authenticated no desactiva el trigger consentimientos_inmutables');
select tests.como_con_proveedor('00000000-0000-0000-0000-000000000024', 'email');
select tests.lanza_con($$update profiles set community_id = 'c0000000-0000-0000-0000-000000000007' where id = '00000000-0000-0000-0000-000000000024'$$,
                       'AT-18', 'C01-S8 (CP-161) Un Director tampoco cambia su propio community_id');
-- Control positivo: mencionar community_id sin cambiarlo (lo que hace un PATCH con la fila completa) sí se permite.
select tests.como_con_proveedor('00000000-0000-0000-0000-000000000023', 'email');
select tests.ok(tests.filas($$update profiles set community_id = 'c0000000-0000-0000-0000-000000000006', full_name = 'Atacante S2'
                              where id = '00000000-0000-0000-0000-000000000023'$$) = 1,
                'C01-SP1 (CP-161) Un update que repite el mismo community_id y cambia full_name sí pasa');
select tests.ok((select count(*) from profiles where community_id = 'c0000000-0000-0000-0000-000000000007') = 0,
                'C01-S9 (CP-161) Tras los intentos, el atacante sigue sin ver a los adultos de la comunidad destino');
reset role;
select tests.ok((select community_id = 'c0000000-0000-0000-0000-000000000006' and full_name = 'Atacante S2'
                 from profiles where id = '00000000-0000-0000-0000-000000000023')
                and (select community_id from profiles where id = '00000000-0000-0000-0000-000000000024') = 'c0000000-0000-0000-0000-000000000006',
                'C01-S1..S8 (CP-161) Los community_id siguen iguales y ningún intento dejó cambios parciales');

-- ── privacy_consents: signup_method sale de app_metadata, nunca de user_metadata ─
set role authenticated;
select tests.con_claims(jsonb_build_object('sub', '00000000-0000-0000-0000-000000000026', 'role', 'authenticated',
                                           'user_metadata', jsonb_build_object('provider', 'google')));
select tests.lanza_con($$select aceptar_aviso_de_privacidad('v0-borrador', '{}')$$, 'metodo de alta',
                       'C01-S10 (CP-162) provider solo en user_metadata (lo escribe el cliente) → se niega');
select tests.con_claims(jsonb_build_object('sub', '00000000-0000-0000-0000-000000000026', 'role', 'authenticated',
                                           'provider', 'google',
                                           'app_metadata', jsonb_build_object('provider', 'email'),
                                           'user_metadata', jsonb_build_object('provider', 'google')));
select tests.ok(aceptar_aviso_de_privacidad('v0-borrador', '{}'),
                'C01-SP2 (CP-162) Con app_metadata.provider = email la RPC registra');
select tests.ok((select bool_and(signup_method = 'correo') from privacy_consents)
                and (select count(*) from privacy_consents) = 4,
                'C01-S11 (CP-162) user_metadata.provider = google y un claim provider suelto no cambian el método: queda correo');

-- RPC con parámetros nulos
select tests.lanza_con($$select aceptar_aviso_de_privacidad(null, '{}')$$, 'version_desactualizada',
                       'C01-S12 (CP-162) RPC con p_version nula → version_desactualizada');
select tests.como_con_proveedor('00000000-0000-0000-0000-000000000025', 'google');
-- Sentencias separadas: una subconsulta en la misma sentencia no ve lo que insertó la función (misma foto).
select tests.ok(aceptar_aviso_de_privacidad('v0-borrador', null), 'C01-SP3 (CP-162) RPC con p_finalidades nula registra');
select tests.ok((select count(*) from privacy_consents where kind = 'finalidad_secundaria' and not granted) = 3,
                'C01-SP3b (CP-162) Con p_finalidades nula las tres finalidades quedan en false');

-- Solo inserción también por otros caminos
select tests.lanza_con($$insert into privacy_consents (id, notice_version, kind, purpose, granted)
                         select id, 'v0-borrador', 'finalidad_secundaria', 'notificaciones', true from privacy_consents
                         where purpose = 'notificaciones'
                         on conflict (id) do update set granted = true$$,
                       'permission denied', 'C01-S13 (CP-162) Upsert (on conflict do update) sobre una fila propia se niega');
select tests.lanza_con($$truncate privacy_consents$$, 'permission denied', 'C01-S14 (CP-162) authenticated no hace truncate de privacy_consents');
select tests.ok((select count(*) from privacy_consents) = 4
                and (select not granted from privacy_consents where purpose = 'notificaciones'),
                'C01-S13/S14 (CP-162) Las filas siguen iguales');
reset role;

set role anon;
select tests.lanza_con($$select privado.version_vigente_del_aviso()$$, 'permission denied',
                       'C01-S15 (CP-162) anon no ejecuta funciones de privado');
reset role;

-- ── service_role sin JWT de usuario no inserta (matriz §3.3) ────────────────────
grant select, insert on public.privacy_consents to service_role;
grant usage on schema tests to service_role;
grant execute on all functions in schema tests to service_role;
set role service_role;
-- Así llega una petición con la llave service_role: claims sin `sub` ni app_metadata.
select set_config('request.jwt.claims', '{"role":"service_role"}', false);
select tests.lanza_con($$insert into privacy_consents (user_id, notice_version, kind, granted, signup_method)
                         values ('00000000-0000-0000-0000-000000000027', 'v0-borrador', 'aviso', true, 'correo')$$,
                       'requiere una sesión', 'C01-S16 (CP-162) service_role sin JWT no inserta un consentimiento a nombre de otro');
reset role;

-- ── Baja de cuenta: el cascade borra los consentimientos (no lo bloquea el trigger) ─
select tests.ok((select count(*) from privacy_consents where user_id = '00000000-0000-0000-0000-000000000025') = 4,
                'C01-SP4 (CP-162) Antes de la baja, la cuenta 25 tiene 4 consentimientos');
select tests.ok(tests.filas($$delete from auth.users where id = '00000000-0000-0000-0000-000000000025'$$) = 1,
                'C01-SP5 (CP-162) La baja en auth.users no la bloquea el trigger de inmutabilidad');
select tests.ok((select count(*) from privacy_consents where user_id = '00000000-0000-0000-0000-000000000025') = 0,
                'C01-SP5b (CP-162) Borrar la cuenta en auth.users borra sus consentimientos en cascada');

-- ── Propiedades de las funciones y políticas nuevas ─────────────────────────────
select tests.ok((select not p.prosecdef and 'search_path=public, pg_temp' = any(p.proconfig)
                 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                 where n.nspname = 'public' and p.proname = 'aceptar_aviso_de_privacidad'),
                'C01-S17 La RPC es security invoker y fija search_path = public, pg_temp');
select tests.ok((select bool_and('search_path=public, pg_temp' = any(p.proconfig)) and count(*) = 4
                 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                 where n.nspname = 'privado' and p.proname in ('version_vigente_del_aviso', 'sellar_consentimiento',
                                                               'consentimiento_inmutable', 'comunidad_inmutable')),
                'C01-S18 Las cuatro funciones nuevas de privado fijan search_path = public, pg_temp');
select tests.ok((select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                 where (n.nspname = 'privado' and p.proname in ('version_vigente_del_aviso', 'sellar_consentimiento',
                                                                'consentimiento_inmutable', 'comunidad_inmutable'))
                    or (n.nspname = 'public' and p.proname = 'aceptar_aviso_de_privacidad')) = 5
                and not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                                where ((n.nspname = 'privado' and p.proname in ('version_vigente_del_aviso', 'sellar_consentimiento',
                                                                                'consentimiento_inmutable', 'comunidad_inmutable'))
                                       or (n.nspname = 'public' and p.proname = 'aceptar_aviso_de_privacidad'))
                                  and (p.prosecdef or p.prosrc ~* '\mexecute\M|format\s*\(')),
                'C01-S19 Ninguna función nueva es security definer ni arma SQL dinámico (execute / format)');
select tests.ok(not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'privacy_consents'
                            and (cmd in ('UPDATE', 'DELETE', 'ALL')
                                 or coalesce(qual, '') ~* '^\(?true\)?$' or coalesce(with_check, '') ~* '^\(?true\)?$')),
                'C01-S20 privacy_consents no tiene políticas de update/delete ni using/with check (true)');
select tests.ok((select count(*) from pg_trigger t join pg_class c on c.oid = t.tgrelid
                 where not t.tgisinternal and t.tgenabled = 'O'
                   and ((c.relname = 'privacy_consents' and t.tgname in ('consentimientos_sellados', 'consentimientos_inmutables'))
                        or (c.relname = 'profiles' and t.tgname = 'perfiles_comunidad_inmutable'))) = 3,
                'C01-S21 Los tres triggers nuevos existen y están habilitados');
select tests.ok(not has_table_privilege('authenticated', 'public.privacy_consents', 'UPDATE')
                and not has_table_privilege('authenticated', 'public.privacy_consents', 'DELETE')
                and not has_table_privilege('authenticated', 'public.privacy_consents', 'TRUNCATE')
                and not has_table_privilege('anon', 'public.privacy_consents', 'SELECT')
                and not has_table_privilege('anon', 'public.privacy_consents', 'INSERT')
                and not has_function_privilege('anon', 'public.aceptar_aviso_de_privacidad(text, public.finalidad_secundaria[])', 'EXECUTE'),
                'C01-S22 Privilegios mínimos: authenticated sin update/delete/truncate; anon sin nada en la tabla ni en la RPC');

rollback;
