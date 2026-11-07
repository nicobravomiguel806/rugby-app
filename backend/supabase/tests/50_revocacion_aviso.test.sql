-- C-01 · H-6 (ronda 1 de corrección): revocación del Aviso de Privacidad como fila nueva (domain-model.md §1,
-- «No aceptar el aviso», excepción; ADR 0009). `privacy_consents` es de solo inserción: revocar inserta una fila
-- `aviso` con `granted = false`. El aviso vigente es su fila más reciente; volver a aceptar inserta otra fila.
-- Casos C01-Rn: los de abuso DEBEN negar; los de control DEBEN permitir.
-- Autosuficiente: usuarios …0030 a …0032, sin perfiles; corre en una transacción que se revierte.
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
-- Valor booleano de una expresión, o null si lanzó error (así una función que falta da «not ok» y no corta el archivo).
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
grant usage on schema tests to authenticated, anon;
grant execute on all functions in schema tests to authenticated, anon;

-- 30 cuenta de correo que aceptó el aviso al volver del enlace (la carrera de H-6) · 31 cuenta de Google sin
-- consentimiento · 32 atacante que intenta revocar por otro
insert into auth.users (id) values
  ('00000000-0000-0000-0000-000000000030'), ('00000000-0000-0000-0000-000000000031'),
  ('00000000-0000-0000-0000-000000000032');

set role authenticated;

-- ── Revocación con consentimiento previo (control) ──────────────────────────────
select tests.como_con_proveedor('00000000-0000-0000-0000-000000000030', 'email');
select tests.ok(tests.valor($$aceptar_aviso_de_privacidad('v0-borrador', '{notificaciones}')$$),
                'C01-R1 (CP-162) Acepta el aviso: la RPC registra y devuelve true');
select tests.ok(tests.valor($$aviso_de_privacidad_aceptado('v0-borrador')$$),
                'C01-R2 (CP-164f) Tras aceptar, el aviso vigente está aceptado');
select tests.ok(tests.valor($$revocar_aviso_de_privacidad('v0-borrador')$$),
                'C01-R3 (CP-164f) «No acepto» con consentimiento previo: la revocación registra y devuelve true');
select tests.ok((select count(*) from privacy_consents where kind = 'aviso') = 2
                and (select count(*) from privacy_consents where kind = 'aviso' and not granted) = 1,
                'C01-R4 (CP-164f) La revocación es una fila nueva del aviso con granted = false (la aceptación sigue)');
select tests.ok((select bool_and(user_id = '00000000-0000-0000-0000-000000000030' and signup_method = 'correo'
                                 and notice_version = 'v0-borrador' and accepted_at = now() and purpose is null)
                 from privacy_consents where kind = 'aviso' and not granted),
                'C01-R5 (CP-162) Usuario, método y fecha de la revocación los pone el servidor');
select tests.ok(tests.valor($$not aviso_de_privacidad_aceptado('v0-borrador')$$),
                'C01-R6 (CP-164f) Tras la revocación, el aviso vigente ya no está aceptado');
select tests.ok(tests.valor($$not revocar_aviso_de_privacidad('v0-borrador')$$),
                'C01-R7 (CP-164f) Revocar otra vez devuelve false (idempotente)');
select tests.ok((select count(*) from privacy_consents where kind = 'aviso') = 2,
                'C01-R7b (CP-164f) Revocar otra vez no agrega filas');

-- ── Volver a aceptar después de revocar (control) ───────────────────────────────
select tests.ok(tests.valor($$aceptar_aviso_de_privacidad('v0-borrador', '{estadisticas}')$$),
                'C01-R8 (CP-164f) Volver a aceptar tras revocar registra y devuelve true');
select tests.ok((select count(*) from privacy_consents where kind = 'aviso') = 3
                and (select count(*) from privacy_consents where kind = 'finalidad_secundaria') = 6,
                'C01-R9 (CP-164f) La nueva aceptación inserta otra fila del aviso y otras tres de finalidades');
select tests.ok(tests.valor($$aviso_de_privacidad_aceptado('v0-borrador')$$),
                'C01-R10 (CP-164f) Tras volver a aceptar, el aviso vigente está aceptado otra vez');
select tests.ok(tests.valor($$not aceptar_aviso_de_privacidad('v0-borrador', '{}')$$),
                'C01-R11 (CP-162) Aceptar otra vez sigue siendo idempotente (false)');
select tests.ok((select count(*) from privacy_consents) = 9,
                'C01-R11b (CP-162) El reintento no agrega filas');

-- ── Sin consentimiento previo no se guarda nada (CA-9) ──────────────────────────
select tests.como_con_proveedor('00000000-0000-0000-0000-000000000031', 'google');
select tests.ok(tests.valor($$not aviso_de_privacidad_aceptado('v0-borrador')$$),
                'C01-R12 (CP-164a) Cuenta de Google sin consentimiento: el aviso no está aceptado');
select tests.ok(tests.valor($$not revocar_aviso_de_privacidad('v0-borrador')$$),
                'C01-R13 (CP-164a) Revocar sin consentimiento previo devuelve false');
select tests.ok((select count(*) from privacy_consents) = 0,
                'C01-R14 (CP-164a) Sin consentimiento previo la revocación no guarda nada');
select tests.lanza_con($$insert into privacy_consents (notice_version, kind, granted) values ('v0-borrador', 'aviso', false)$$,
                       'aviso_sin_cambio', 'C01-R15 (CP-162) Un insert directo de revocación sin aceptación previa se niega');

-- ── No se revoca por otro usuario (abuso) ───────────────────────────────────────
select tests.como_con_proveedor('00000000-0000-0000-0000-000000000032', 'email');
select tests.ok(tests.valor($$not revocar_aviso_de_privacidad('v0-borrador')$$),
                'C01-R16 (CP-162) La RPC de revocación solo actúa sobre auth.uid(): para el atacante no hay nada que revocar');
select tests.lanza_con($$insert into privacy_consents (user_id, notice_version, kind, granted)
                         values ('00000000-0000-0000-0000-000000000030', 'v0-borrador', 'aviso', false)$$,
                       'row-level security', 'C01-R17 (CP-162) Un insert de revocación con el user_id de otro usuario se niega');
select tests.ok((select count(*) from privacy_consents) = 0,
                'C01-R18 (CP-162) El atacante no ve los consentimientos de la víctima');
select tests.como_con_proveedor('00000000-0000-0000-0000-000000000030', 'email');
select tests.ok((select count(*) from privacy_consents where kind = 'aviso') = 3
                and tests.valor($$aviso_de_privacidad_aceptado('v0-borrador')$$),
                'C01-R19 (CP-162) La víctima sigue con 3 filas del aviso y con el aviso aceptado');
select tests.lanza_con($$insert into privacy_consents (notice_version, kind, granted) values ('v0-borrador', 'aviso', true)$$,
                       'aviso_sin_cambio', 'C01-R20 (CP-162) Un insert directo que repite la aceptación vigente se niega');
reset role;

-- ── anon y propiedades de las funciones nuevas ──────────────────────────────────
set role anon;
select tests.lanza_con($$select revocar_aviso_de_privacidad('v0-borrador')$$, 'permission denied',
                       'C01-R21 (CP-162) anon no llama a la RPC de revocación');
select tests.lanza_con($$select aviso_de_privacidad_aceptado('v0-borrador')$$, 'permission denied',
                       'C01-R22 (CP-162) anon no llama a la consulta del aviso');
reset role;
select tests.ok((select count(*) = 2 and bool_and(not p.prosecdef and 'search_path=public, pg_temp' = any(p.proconfig)
                                                  and p.prosrc !~* '\mexecute\M|format\s*\(')
                 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                 where n.nspname = 'public' and p.proname in ('revocar_aviso_de_privacidad', 'aviso_de_privacidad_aceptado')),
                'C01-R23 Las dos RPC nuevas son security invoker, fijan search_path y no arman SQL dinámico');
select tests.ok((select count(*) = 2 and bool_and(not p.prosecdef and 'search_path=public, pg_temp' = any(p.proconfig)
                                                  and p.prosrc !~* '\mexecute\M|format\s*\(')
                 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                 where n.nspname = 'privado' and p.proname in ('aviso_vigente', 'bloquear_aviso')),
                'C01-R24 Las dos funciones nuevas de privado son security invoker, fijan search_path y no arman SQL dinámico');
select tests.ok((select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                 where n.nspname = 'public' and p.prosecdef) = 0
                and not has_table_privilege('authenticated', 'public.privacy_consents', 'UPDATE')
                and not has_table_privilege('authenticated', 'public.privacy_consents', 'DELETE')
                and not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'privacy_consents'
                                and cmd in ('UPDATE', 'DELETE', 'ALL')),
                'C01-R25 (CP-151a) Sin security definer en public; privacy_consents sigue sin update ni delete para authenticated');

rollback;
