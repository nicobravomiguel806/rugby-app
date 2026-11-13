-- C-01 · Pruebas del agente de seguridad (ronda 2): ataques al diseño nuevo de `privacy_consents` tras H-6
-- (revocación = fila nueva; sin índice único; trigger de sellado con `aviso_sin_cambio`; candado
-- `privado.bloquear_aviso`; estado vigente con `privado.aviso_vigente`; RPC `revocar_aviso_de_privacidad` y
-- `aviso_de_privacidad_aceptado`). Casos C01-V*: los de abuso DEBEN negar; los C01-VP* son controles que DEBEN permitir.
-- Autosuficiente: usuarios …0040 a …0043, sin perfiles; corre en una transacción que se revierte.
-- Las carreras entre dos conexiones no se pueden probar en una sola sesión de psql: aquí se prueba que el candado se
-- toma (pg_locks) y la carrera real se reprodujo a mano con dos sesiones (§6 ronda 2 del contrato, H-11).
\set ON_ERROR_STOP on
set client_min_messages = notice;
reset role;
begin;

create schema if not exists tests;
create or replace function tests.ok(cond boolean, nombre text) returns void language plpgsql as $$
begin
  if coalesce(cond, false) then raise notice 'ok - %', nombre; else raise notice 'not ok - %', nombre; end if;
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
create or replace function tests.valor(expresion text) returns boolean language plpgsql as $$
declare v boolean;
begin
  execute 'select (' || expresion || ')::boolean' into v;
  return v;
exception when others then
  raise notice '# % → %', expresion, sqlerrm;
  return null;
end $$;
create or replace function tests.como_con_proveedor(usuario uuid, proveedor text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object(
    'sub', usuario, 'role', 'authenticated', 'app_metadata', json_build_object('provider', proveedor))::text, false);
$$;
-- Candados de aviso que tiene esta sesión (pg_advisory_xact_lock con llave de 64 bits).
create or replace function tests.candados_propios() returns bigint language sql as $$
  select count(*) from pg_locks where locktype = 'advisory' and pid = pg_backend_pid() and granted;
$$;
grant usage on schema tests to authenticated, anon, service_role;
grant execute on all functions in schema tests to authenticated, anon, service_role;

-- 40 víctima (correo) · 41 atacante (correo) · 42 cuenta de Google sin consentimiento · 43 baja de cuenta
insert into auth.users (id) values
  ('00000000-0000-0000-0000-000000000040'), ('00000000-0000-0000-0000-000000000041'),
  ('00000000-0000-0000-0000-000000000042'), ('00000000-0000-0000-0000-000000000043');

-- ── Candado (la carrera aceptar / revocar) ──────────────────────────────────────
set role authenticated;
select tests.como_con_proveedor('00000000-0000-0000-0000-000000000040', 'email');
select tests.ok(tests.candados_propios() = 0, 'C01-V0 (preparación) La sesión empieza sin candados de aviso');
select tests.ok(tests.valor($$not revocar_aviso_de_privacidad('v0-borrador')$$)
                and tests.candados_propios() = 1,
                'C01-V1 (CP-164f) revocar toma el candado por usuario y versión aunque no haya nada que revocar (serializa con aceptar)');
select tests.ok(tests.valor($$aceptar_aviso_de_privacidad('v0-borrador', '{notificaciones}')$$)
                and tests.candados_propios() = 1,
                'C01-VP1 (CP-162) La víctima acepta: aceptar reutiliza el mismo candado (misma llave)');
select tests.como_con_proveedor('00000000-0000-0000-0000-000000000042', 'google');
insert into privacy_consents (notice_version, kind, granted) values ('v0-borrador', 'aviso', true);
select tests.ok(tests.candados_propios() = 2,
                'C01-V2 (CP-162) Un insert directo del aviso también toma el candado (del trigger), con llave propia del usuario');

-- ── Varias filas en una sentencia o transacción con el mismo now() ──────────────
select tests.como_con_proveedor('00000000-0000-0000-0000-000000000041', 'email');
select tests.lanza_con($$insert into privacy_consents (notice_version, kind, granted)
                         values ('v0-borrador', 'aviso', true), ('v0-borrador', 'aviso', true)$$,
                       'aviso_sin_cambio', 'C01-V3 (CP-162) Dos aceptaciones en un mismo insert de varias filas se niegan');
select tests.lanza_con($$insert into privacy_consents (notice_version, kind, granted)
                         select 'v0-borrador', 'aviso', true from generate_series(1, 3)$$,
                       'aviso_sin_cambio', 'C01-V4 (CP-162) insert … select de tres aceptaciones se niega');
select tests.lanza_con($$with a as (select aceptar_aviso_de_privacidad('v0-borrador', '{}') as r)
                         insert into privacy_consents (notice_version, kind, granted) select 'v0-borrador', 'aviso', true from a$$,
                       'aviso_sin_cambio', 'C01-V5 (CP-162) RPC y un insert directo en la misma sentencia (CTE) no dejan dos aceptaciones');
select tests.lanza_con($$with a as (insert into privacy_consents (notice_version, kind, granted) values ('v0-borrador', 'aviso', true) returning 1)
                         insert into privacy_consents (notice_version, kind, granted) values ('v0-borrador', 'aviso', true)$$,
                       'aviso_sin_cambio', 'C01-V6 (CP-162) Dos inserts en CTE de la misma sentencia no dejan dos aceptaciones');
select tests.ok((select count(*) from privacy_consents) = 0, 'C01-V6b (CP-162) Los intentos anteriores no dejaron filas');
select tests.ok(tests.valor($$aceptar_aviso_de_privacidad('v0-borrador', '{}')$$),
                'C01-VP2 (CP-162) Control: el atacante sí acepta su propio aviso con la RPC');
select tests.lanza_con($$insert into privacy_consents (notice_version, kind, granted) values ('v0-borrador', 'aviso', true)$$,
                       'aviso_sin_cambio', 'C01-V7 (CP-162) En la misma transacción (mismo now()), un insert directo que repite la aceptación se niega');
select tests.ok(tests.valor($$revocar_aviso_de_privacidad('v0-borrador')$$),
                'C01-VP3 (CP-164f) Control: en la misma transacción se puede revocar');
select tests.lanza_con($$insert into privacy_consents (notice_version, kind, granted)
                         values ('v0-borrador', 'aviso', false), ('v0-borrador', 'aviso', false)$$,
                       'aviso_sin_cambio', 'C01-V8 (CP-164f) Dos revocaciones seguidas en un insert de varias filas se niegan');
select tests.ok(tests.valor($$not aviso_de_privacidad_aceptado('v0-borrador')$$)
                and (select count(*) from privacy_consents where kind = 'aviso') = 2,
                'C01-V8b (CP-164f) Con todas las filas del mismo now(), el estado vigente sigue siendo «revocado» (no depende del orden)');

-- ── accepted_at e id del cliente no mueven el estado vigente ────────────────────
select tests.ok(tests.valor($$aceptar_aviso_de_privacidad('v0-borrador', '{}')$$),
                'C01-VP4 (CP-164f) Control: volver a aceptar tras revocar');
insert into privacy_consents (id, notice_version, kind, granted, accepted_at)
values ('ffffffff-ffff-ffff-ffff-ffffffffffff', 'v0-borrador', 'aviso', false, '1999-01-01');
select tests.ok((select accepted_at = now() from privacy_consents where id = 'ffffffff-ffff-ffff-ffff-ffffffffffff'),
                'C01-V9 (CP-162) Una revocación con accepted_at antiguo del cliente queda con now()');
select tests.ok(tests.valor($$not aviso_de_privacidad_aceptado('v0-borrador')$$),
                'C01-V10 (CP-164f) Ni el accepted_at ni el id elegidos por el cliente hacen vigente la aceptación anterior');
select tests.lanza_con($$insert into privacy_consents (id, notice_version, kind, granted, accepted_at)
                         values ('00000000-0000-0000-0000-000000000000', 'v0-borrador', 'aviso', false, '2999-01-01')$$,
                       'aviso_sin_cambio', 'C01-V11 (CP-162) Una revocación «del futuro» sobre un aviso ya revocado se niega');

-- ── Finalidades sin aviso, otra versión y forma ─────────────────────────────────
select tests.como_con_proveedor('00000000-0000-0000-0000-000000000043', 'email');
insert into privacy_consents (notice_version, kind, purpose, granted)
values ('v0-borrador', 'finalidad_secundaria', 'notificaciones', true);
select tests.ok(tests.valor($$not aviso_de_privacidad_aceptado('v0-borrador')$$),
                'C01-V12 (CP-114) Una finalidad insertada sin aviso no cuenta como aceptación del aviso');
select tests.ok(tests.valor($$not revocar_aviso_de_privacidad('v0-borrador')$$)
                and (select count(*) from privacy_consents where kind = 'aviso') = 0,
                'C01-V13 (CP-164a) Con solo finalidades, revocar no registra nada');
select tests.lanza_con($$insert into privacy_consents (notice_version, kind, granted) values ('v1', 'aviso', true)$$,
                       'version_desactualizada', 'C01-V14 (CP-162) Insert directo del aviso con otra versión se niega');
select tests.lanza_con($$insert into privacy_consents (notice_version, kind, granted) values ('v1', 'aviso', false)$$,
                       'version_desactualizada', 'C01-V15 (CP-162) Insert directo de revocación con otra versión se niega');
select tests.lanza_con($$select aceptar_aviso_de_privacidad('v1', '{}')$$,
                       'version_desactualizada', 'C01-V16 (CP-162) La RPC de aceptación con otra versión se niega');
select tests.ok(tests.valor($$not revocar_aviso_de_privacidad('v1')$$)
                and tests.valor($$not revocar_aviso_de_privacidad(null)$$)
                and tests.valor($$not aviso_de_privacidad_aceptado('v1')$$)
                and tests.valor($$not aviso_de_privacidad_aceptado(null)$$),
                'C01-V17 (CP-164f) revocar y consultar con otra versión o con null devuelven false sin error');
select tests.lanza_con($$insert into privacy_consents (notice_version, kind, purpose, granted)
                         values ('v0-borrador', 'aviso', 'notificaciones', true)$$,
                       'privacy_consents_forma', 'C01-V18 (CP-162) Un aviso con finalidad se niega (check)');
select tests.ok((select count(*) from privacy_consents) = 1, 'C01-V18b (CP-162) Solo quedó la finalidad');

-- ── Revocar o aceptar por otro usuario ──────────────────────────────────────────
select tests.como_con_proveedor('00000000-0000-0000-0000-000000000041', 'email');
select tests.lanza_con($$insert into privacy_consents (user_id, notice_version, kind, granted)
                         values ('00000000-0000-0000-0000-000000000040', 'v0-borrador', 'aviso', false)$$,
                       'row-level security', 'C01-V19 (CP-162) El atacante no revoca por la víctima con un insert directo');
select tests.lanza_con($$insert into privacy_consents (user_id, notice_version, kind, granted)
                         values ('00000000-0000-0000-0000-000000000042', 'v0-borrador', 'aviso', false)$$,
                       'row-level security', 'C01-V20 (CP-162) El atacante no revoca por la cuenta de Google');
select tests.lanza_con($$insert into privacy_consents (user_id, notice_version, kind, granted)
                         values ('00000000-0000-0000-0000-000000000043', 'v0-borrador', 'aviso', true)$$,
                       'row-level security', 'C01-V21 (CP-162) El atacante no acepta el aviso a nombre de otro usuario');
select tests.ok(tests.valor($$not privado.aviso_vigente('00000000-0000-0000-0000-000000000040', 'v0-borrador')$$),
                'C01-V22 (CP-162) privado.aviso_vigente con el id de la víctima no filtra su estado (RLS: invoker)');
select tests.ok((select count(*) = 0 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                 where n.nspname = 'public'
                   and p.proname in ('aceptar_aviso_de_privacidad', 'revocar_aviso_de_privacidad', 'aviso_de_privacidad_aceptado')
                   and pg_get_function_identity_arguments(p.oid) ~* 'uuid'),
                'C01-V23 (CP-162) Ninguna de las tres RPC recibe un usuario: solo actúan sobre auth.uid()');
select tests.como_con_proveedor('00000000-0000-0000-0000-000000000040', 'email');
select tests.ok(tests.valor($$aviso_de_privacidad_aceptado('v0-borrador')$$)
                and (select count(*) from privacy_consents) = 4,
                'C01-VP5 (CP-162) La víctima sigue con su aceptación y sus 4 filas');
reset role;

-- ── anon y service_role sin JWT ─────────────────────────────────────────────────
select tests.ok(not has_function_privilege('anon', 'public.revocar_aviso_de_privacidad(text)', 'EXECUTE')
                and not has_function_privilege('anon', 'public.aviso_de_privacidad_aceptado(text)', 'EXECUTE')
                and not has_function_privilege('anon', 'public.aceptar_aviso_de_privacidad(text, public.finalidad_secundaria[])', 'EXECUTE')
                and not has_function_privilege('anon', 'privado.aviso_vigente(uuid, text)', 'EXECUTE')
                and not has_function_privilege('anon', 'privado.bloquear_aviso(uuid, text)', 'EXECUTE')
                and not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace,
                                aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
                                where (n.nspname, p.proname) in (('public', 'revocar_aviso_de_privacidad'),
                                                                 ('public', 'aviso_de_privacidad_aceptado'),
                                                                 ('privado', 'aviso_vigente'), ('privado', 'bloquear_aviso'))
                                  and a.grantee = 0 and a.privilege_type = 'EXECUTE'),
                'C01-V24 (CP-162) Ni anon ni PUBLIC ejecutan las RPC ni las funciones nuevas de privado');
set role anon;
select tests.lanza_con($$select privado.aviso_vigente('00000000-0000-0000-0000-000000000040', 'v0-borrador')$$,
                       'permission denied', 'C01-V25 (CP-162) anon no consulta el aviso vigente de nadie');
select tests.lanza_con($$select privado.bloquear_aviso('00000000-0000-0000-0000-000000000040', 'v0-borrador')$$,
                       'permission denied', 'C01-V26 (CP-162) anon no toma el candado del aviso de otro');
select tests.lanza_con($$select aceptar_aviso_de_privacidad('v0-borrador', '{}')$$,
                       'permission denied', 'C01-V27 (CP-162) anon no acepta');
reset role;

-- En Supabase, service_role recibe por defecto execute en las funciones y todos los privilegios en las tablas de
-- public. Se simula aquí (la transacción se revierte) para probar que sin JWT de usuario no escribe ni revoca.
grant execute on function public.aceptar_aviso_de_privacidad(text, public.finalidad_secundaria[]) to service_role;
grant execute on function public.revocar_aviso_de_privacidad(text) to service_role;
grant execute on function public.aviso_de_privacidad_aceptado(text) to service_role;
grant usage on schema privado to service_role;
grant execute on function privado.aviso_vigente(uuid, text), privado.bloquear_aviso(uuid, text),
  privado.version_vigente_del_aviso(), privado.sellar_consentimiento(), privado.consentimiento_inmutable() to service_role;
grant select, insert, update on public.privacy_consents to service_role;
set role service_role;
select set_config('request.jwt.claims', '{"role":"service_role"}', false);
select tests.lanza_con($$select aceptar_aviso_de_privacidad('v0-borrador', '{}')$$,
                       'requiere una sesión', 'C01-V28 (CP-162) service_role sin JWT no acepta (no hay auth.uid())');
select tests.ok(tests.valor($$not revocar_aviso_de_privacidad('v0-borrador')$$)
                and tests.valor($$not aviso_de_privacidad_aceptado('v0-borrador')$$),
                'C01-V29 (CP-164f) service_role sin JWT: revocar y consultar devuelven false');
select tests.lanza_con($$insert into privacy_consents (user_id, notice_version, kind, granted, signup_method)
                         values ('00000000-0000-0000-0000-000000000040', 'v0-borrador', 'aviso', false, 'correo')$$,
                       'requiere una sesión', 'C01-V30 (CP-162) service_role sin JWT no revoca por la víctima con un insert directo');
select tests.lanza_con($$update privacy_consents set granted = false where user_id = '00000000-0000-0000-0000-000000000040'$$,
                       'solo inserción', 'C01-V31 (CP-162) Ni service_role cambia una aceptación a revocación con update');
reset role;

-- ── Solo inserción para authenticated ───────────────────────────────────────────
set role authenticated;
select tests.como_con_proveedor('00000000-0000-0000-0000-000000000040', 'email');
select tests.lanza_con($$update privacy_consents set granted = false where kind = 'aviso'$$,
                       'permission denied', 'C01-V32 (CP-162) La víctima no revoca con update');
select tests.lanza_con($$delete from privacy_consents where kind = 'aviso'$$,
                       'permission denied', 'C01-V33 (CP-162) No se borra la aceptación para «revocar»');
select tests.lanza_con($$truncate privacy_consents$$, 'permission denied', 'C01-V34 (CP-162) No se vacía la tabla');
reset role;
select tests.ok(not has_table_privilege('authenticated', 'public.privacy_consents', 'UPDATE')
                and not has_table_privilege('authenticated', 'public.privacy_consents', 'DELETE')
                and not has_table_privilege('authenticated', 'public.privacy_consents', 'TRUNCATE')
                and not has_table_privilege('authenticated', 'public.privacy_consents', 'TRIGGER')
                and not has_table_privilege('authenticated', 'public.privacy_consents', 'REFERENCES')
                and (select relrowsecurity from pg_class where oid = 'public.privacy_consents'::regclass),
                'C01-V35 (CP-162) authenticated solo tiene select e insert y la RLS sigue activa');
select tests.lanza_con($$update privacy_consents set accepted_at = now() - interval '1 day'$$,
                       'solo inserción', 'C01-V36 (CP-162) Ni el dueño (superusuario) reordena el historial con update');
select tests.ok((select count(*) = 2 and bool_and(tgenabled = 'O')
                 from pg_trigger where tgrelid = 'public.privacy_consents'::regclass and not tgisinternal),
                'C01-V37 (CP-162) Los dos triggers de privacy_consents siguen habilitados');
select tests.ok(not exists (select 1 from pg_indexes where schemaname = 'public' and tablename = 'privacy_consents'
                            and indexdef ~* 'unique' and indexname <> 'privacy_consents_pkey'),
                'C01-V38 (CP-164f) No queda el índice único del aviso (la revocación depende del trigger y del candado)');

-- ── Propiedades de las funciones cambiadas o nuevas ─────────────────────────────
select tests.ok((select count(*) = 6 and bool_and(not p.prosecdef and 'search_path=public, pg_temp' = any(p.proconfig)
                                                  and p.prosrc !~* '\mexecute\M|format\s*\(|quote_')
                 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                 where (n.nspname, p.proname) in (('public', 'aceptar_aviso_de_privacidad'),
                                                  ('public', 'revocar_aviso_de_privacidad'),
                                                  ('public', 'aviso_de_privacidad_aceptado'),
                                                  ('privado', 'sellar_consentimiento'),
                                                  ('privado', 'aviso_vigente'),
                                                  ('privado', 'bloquear_aviso'))),
                'C01-V39 Las seis funciones del diff son security invoker, fijan search_path y no arman SQL dinámico');
select tests.ok((select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                 where n.nspname = 'public' and p.prosecdef) = 0,
                'C01-V40 (CP-151a) Sigue sin haber security definer en public');

-- ── Cascade de la baja de cuenta ────────────────────────────────────────────────
-- La víctima tiene aceptación; se le agrega revocación y otra aceptación para que la baja borre un historial completo.
set role authenticated;
select tests.como_con_proveedor('00000000-0000-0000-0000-000000000040', 'email');
select tests.ok(tests.valor($$revocar_aviso_de_privacidad('v0-borrador')$$), 'C01-VP6 (CP-164f) Control: la víctima revoca');
reset role;
create temp table antes_de_la_baja as
  select (select count(*) from privacy_consents where user_id = '00000000-0000-0000-0000-000000000040') as victima,
         (select count(*) from privacy_consents where user_id <> '00000000-0000-0000-0000-000000000040') as resto;
delete from auth.users where id = '00000000-0000-0000-0000-000000000040';
select tests.ok((select victima = 5 and resto > 0 from antes_de_la_baja)
                and (select count(*) from privacy_consents where user_id = '00000000-0000-0000-0000-000000000040') = 0
                and (select count(*) from privacy_consents) = (select resto from antes_de_la_baja),
                'C01-V41 (CP-162) La baja en auth.users borra en cascade la aceptación y la revocación, y solo las de esa cuenta');

rollback;
