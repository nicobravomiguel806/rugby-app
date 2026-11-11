-- C-02 · Pruebas del agente de seguridad (ronda 1). C-02 no trae esquema nuevo: lo único del servidor que usa la
-- revocación pendiente (ADR 0010) es la RPC `revocar_aviso_de_privacidad(p_version)` de C-01, llamada con el access
-- token que sale del refresh de la sesión vieja. Aquí se ataca esa parte de la matriz rol → acción de §3.3:
-- «Revocación pendiente en el dispositivo · Revocar su aviso (RPC): ✅ solo la de su usuarioId» y
-- «anon · Revocar su aviso (RPC): ❌». Casos C02-S*: los de abuso DEBEN negar; los C02-SP* son controles que DEBEN permitir.
-- Autosuficiente: usuarios …0070 (A, dueño de la pendiente) y …0071 (B, otra cuenta), sin perfiles; se revierte.
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
-- `sesion`: el claim `session_id` del JWT. Cada refresh de la sesión vieja conserva el de esa sesión (S1); un inicio
-- nuevo de la misma cuenta trae otro (S2).
create or replace function tests.como_en_sesion(usuario uuid, sesion text, rol text default 'authenticated') returns void
language sql as $$
  select set_config('request.jwt.claims', json_build_object(
    'sub', usuario, 'role', rol, 'session_id', sesion,
    'app_metadata', json_build_object('provider', 'email'))::text, false);
$$;
grant usage on schema tests to authenticated, anon, service_role;
grant execute on all functions in schema tests to authenticated, anon, service_role;

insert into auth.users (id) values ('00000000-0000-0000-0000-000000000070'), ('00000000-0000-0000-0000-000000000071');

-- ── Forma de la RPC (lo que hace que la pendiente no pueda apuntar a otra cuenta) ───────────────────────────────
select tests.ok((select count(*) = 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                 where n.nspname = 'public' and p.proname = 'revocar_aviso_de_privacidad'),
                'C02-S1 (C02-1) revocar_aviso_de_privacidad no tiene sobrecargas');
select tests.ok((select p.pronargs = 1 and p.proargtypes[0] = 'text'::regtype
                 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                 where n.nspname = 'public' and p.proname = 'revocar_aviso_de_privacidad'),
                'C02-S1b (C02-1) La RPC solo recibe la versión: no hay parámetro de usuario (autoría = auth.uid())');
select tests.ok((select not p.prosecdef and p.proconfig @> array['search_path=public, pg_temp']
                 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                 where n.nspname = 'public' and p.proname = 'revocar_aviso_de_privacidad'),
                'C02-S1c La RPC es security invoker y fija search_path = public, pg_temp');
select tests.ok(not has_function_privilege('anon', 'public.revocar_aviso_de_privacidad(text)', 'execute')
                and has_function_privilege('authenticated', 'public.revocar_aviso_de_privacidad(text)', 'execute'),
                'C02-S1d Solo authenticated ejecuta la RPC (anon no)');

-- ── anon: ❌ revocar el aviso, aun con el sub de la víctima en los claims ────────────────────────────────────────
-- B acepta el aviso (estado previo de la víctima).
set role authenticated;
select tests.como_en_sesion('00000000-0000-0000-0000-000000000071', 'sesion-b');
select tests.ok(tests.valor($$aceptar_aviso_de_privacidad('v0-borrador', '{}')$$), 'C02-SP0 (preparación) B acepta el aviso');
reset role;

set role anon;
select tests.como_en_sesion('00000000-0000-0000-0000-000000000071', 'sesion-b', 'anon');
select tests.lanza_con($$select revocar_aviso_de_privacidad('v0-borrador')$$, 'permission denied',
                       'C02-S2 (matriz: anon ❌) Una pendiente sin access token (solo la llave anon) no revoca el aviso, aunque los claims digan B');
reset role;

-- ── Pendiente de A con el access token de A: ❌ sobre la cuenta de B ──────────────────────────────────────────────
set role authenticated;
select tests.como_en_sesion('00000000-0000-0000-0000-000000000070', 'sesion-a-vieja');
select tests.ok(tests.valor($$not revocar_aviso_de_privacidad('v0-borrador')$$),
                'C02-S3 (C02-1) La pendiente de A (sin aviso propio) no revoca nada: devuelve false');
select tests.ok((select count(*) = 0 from privacy_consents where user_id = '00000000-0000-0000-0000-000000000071'),
                'C02-S3b (C02-1) La pendiente de A no ve ni toca las filas de B (RLS)');
select tests.como_en_sesion('00000000-0000-0000-0000-000000000071', 'sesion-b');
select tests.ok(tests.valor($$aviso_de_privacidad_aceptado('v0-borrador')$$)
                and (select count(*) = 1 from privacy_consents where kind = 'aviso'),
                'C02-S3c (C02-1) B sigue con el aviso aceptado y sin fila de revocación');

-- ── Control ✅: la pendiente revoca el aviso de SU cuenta, una sola vez ─────────────────────────────────────────
select tests.como_en_sesion('00000000-0000-0000-0000-000000000070', 'sesion-a-vieja');
select tests.ok(tests.valor($$aceptar_aviso_de_privacidad('v0-borrador', '{}')$$), 'C02-SP1 (preparación) A acepta en la sesión vieja');
select tests.ok(tests.valor($$revocar_aviso_de_privacidad('v0-borrador')$$)
                and tests.valor($$not aviso_de_privacidad_aceptado('v0-borrador')$$),
                'C02-SP2 (CA-7, CP-168a) Control: la pendiente de A revoca el aviso de A');
select tests.ok(tests.valor($$not revocar_aviso_de_privacidad('v0-borrador')$$)
                and (select count(*) = 2 from privacy_consents where kind = 'aviso'),
                'C02-SP3 (CA-7) Reintentar la misma pendiente es idempotente: false y sin fila nueva');
select tests.ok((select bool_and(user_id = '00000000-0000-0000-0000-000000000070' and accepted_at = now())
                 from privacy_consents where kind = 'aviso'),
                'C02-SP4 Autoría y hora de la revocación las pone el servidor (auth.uid(), now())');

-- ── P-4 en el servidor: la RPC NO distingue sesiones (evidencia de H-1 en §6) ───────────────────────────────────
-- A vuelve a iniciar sesión (S2) y acepta el aviso otra vez. Una llamada con el token refrescado de la sesión vieja
-- (S1) revoca la aceptación NUEVA: «no tocar la aceptación nueva» (P-4) depende solo de que el cliente quite el aviso
-- de la pendiente (`quitarAviso`) antes de que la RPC se llame. Esta prueba describe el diseño aprobado (sin esquema
-- nuevo en C-02); si un día la RPC se liga a la sesión, debe invertirse.
select tests.como_en_sesion('00000000-0000-0000-0000-000000000070', 'sesion-a-nueva');
select tests.ok(tests.valor($$aceptar_aviso_de_privacidad('v0-borrador', '{}')$$), 'C02-SP5 (preparación) A acepta en la sesión nueva S2');
select tests.como_en_sesion('00000000-0000-0000-0000-000000000070', 'sesion-a-vieja');
select tests.ok(tests.valor($$revocar_aviso_de_privacidad('v0-borrador')$$),
                'C02-S4 (documenta H-1) La RPC con el token de la sesión vieja S1 revoca la aceptación hecha en S2: P-4 solo lo protege el cliente');

rollback;
