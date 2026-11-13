-- C-01 · Registro de usuario: consentimiento del Aviso de Privacidad en el servidor (RNF-10, LFPDPPP, ADR 0009)
-- y `community_id` inmutable para el usuario (AT-18 parte a). Reglas en docs/domain-model.md §0 y §1.
--
-- 1) Tipos nuevos.
-- 2) `privacy_consents`: evidencia del consentimiento, una fila por decisión. El servidor pone el usuario, la fecha y
--    el método de alta (desde el JWT firmado); de solo inserción.
-- 3) RPC `aceptar_aviso_de_privacidad`: aviso + una fila por finalidad, idempotente, `security invoker` (RLS aplica).
--    H-6 (ronda 1 de corrección): `revocar_aviso_de_privacidad` (revocación = fila nueva del aviso con
--    `granted = false`) y `aviso_de_privacidad_aceptado` (el aviso vigente es su fila más reciente).
-- 4) Trigger `perfiles_comunidad_inmutable` sobre `profiles`.

-- ── 1. Tipos ────────────────────────────────────────────────────────────────────
create type public.tipo_consentimiento as enum ('aviso', 'finalidad_secundaria');
-- SP-07 agrega 'apple' con `alter type … add value`.
create type public.metodo_de_alta as enum ('correo', 'google');
-- Las tres finalidades secundarias del aviso v0-borrador (§3). Mismos valores que FinalidadSecundaria en Domain.
create type public.finalidad_secundaria as enum ('notificaciones', 'comunicaciones', 'estadisticas');

-- ── 2. privacy_consents ─────────────────────────────────────────────────────────
create table public.privacy_consents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  notice_version text not null,
  kind public.tipo_consentimiento not null,
  purpose public.finalidad_secundaria,
  granted boolean not null,
  signup_method public.metodo_de_alta not null,
  accepted_at timestamptz not null default now(),
  constraint privacy_consents_forma check (
    (kind = 'aviso' and purpose is null)
    or (kind = 'finalidad_secundaria' and purpose is not null)
  )
);
comment on table public.privacy_consents is
  'C-01 · Evidencia del consentimiento del Aviso de Privacidad (LFPDPPP). Solo inserción; usuario, fecha y método los pone el servidor (ADR 0009).';

-- El estado vigente del aviso y de cada finalidad es su fila más reciente. En el aviso, `granted = false` es una
-- revocación (H-6). El trigger de sellado obliga a que cada fila del aviso cambie el estado vigente (aceptar →
-- revocar → aceptar…), así que no hay dos aceptaciones vigentes seguidas ni revocaciones sin aceptación previa.
create index privacy_consents_por_usuario on public.privacy_consents (user_id, accepted_at desc);

-- Versión vigente del aviso. Cambiar de versión = migración nueva + pedir aceptación otra vez (aviso §8).
create or replace function privado.version_vigente_del_aviso() returns text
language sql immutable set search_path = public, pg_temp as $$
  select 'v0-borrador'::text;
$$;

-- H-6 · ¿Está aceptado el aviso de esa versión para ese usuario? El estado vigente es su fila más reciente. Como las
-- filas del aviso alternan (aceptar, revocar, aceptar…; lo exige `sellar_consentimiento`), la más reciente es una
-- aceptación si y solo si hay más aceptaciones que revocaciones. Se cuenta en lugar de ordenar por `accepted_at`
-- porque dos filas de la misma transacción tienen el mismo `now()`. `security invoker`: RLS deja ver solo las propias.
create or replace function privado.aviso_vigente(p_usuario uuid, p_version text) returns boolean
language sql stable security invoker set search_path = public, pg_temp as $$
  select count(*) filter (where granted) > count(*) filter (where not granted)
  from privacy_consents
  where user_id = p_usuario and notice_version = p_version and kind = 'aviso';
$$;

-- H-6 · Serializa los cambios del aviso de un usuario y versión hasta el fin de la transacción, para que dos
-- aceptaciones (o revocaciones) simultáneas no inserten dos filas iguales. Sustituye al índice único anterior.
create or replace function privado.bloquear_aviso(p_usuario uuid, p_version text) returns void
language sql volatile security invoker set search_path = public, pg_temp as $$
  select pg_advisory_xact_lock(hashtextextended('privacy_consents/' || coalesce(p_usuario::text, '') || '/' || coalesce(p_version, ''), 0));
$$;

-- Sella la fila antes de insertar: autoría, fecha y método son del servidor; lo que mande el cliente se ignora.
-- `security invoker`: corre con los permisos del usuario. Las políticas `with check` se evalúan después.
create or replace function privado.sellar_consentimiento() returns trigger
language plpgsql security invoker set search_path = public, pg_temp as $$
declare
  proveedor text := auth.jwt() -> 'app_metadata' ->> 'provider';
begin
  if auth.uid() is null then
    raise exception 'privacy_consents requiere una sesión de usuario' using errcode = '42501';
  end if;
  if new.notice_version is distinct from privado.version_vigente_del_aviso() then
    raise exception 'version_desactualizada' using errcode = '22023';
  end if;
  new.accepted_at := now();
  new.signup_method := case proveedor
    when 'email' then 'correo'::public.metodo_de_alta
    when 'google' then 'google'::public.metodo_de_alta
    else null
  end;
  if new.signup_method is null then
    raise exception 'metodo de alta no admitido: %', coalesce(proveedor, '(sin proveedor)') using errcode = '22023';
  end if;
  -- H-6 · Cada fila del aviso cambia el estado vigente: no se repite una aceptación vigente ni se revoca sin
  -- aceptación previa (CA-9: sin consentimiento, «No acepto» no guarda nada). Una fila a nombre de otro usuario la
  -- niega después la política `consentimientos_alta`.
  if new.kind = 'aviso' and new.user_id = auth.uid() then
    perform privado.bloquear_aviso(new.user_id, new.notice_version);
    if new.granted is not distinct from privado.aviso_vigente(new.user_id, new.notice_version) then
      raise exception 'aviso_sin_cambio: la fila no cambia el estado vigente del aviso' using errcode = '23505';
    end if;
  end if;
  return new;
end $$;

-- Nadie edita un consentimiento, ni siquiera service_role. No cubre `delete`: bloquearía el `cascade` de la baja
-- de cuenta en auth.users. Para `authenticated` el `delete` ya está negado por privilegios y por RLS.
create or replace function privado.consentimiento_inmutable() returns trigger
language plpgsql set search_path = public, pg_temp as $$
begin
  raise exception 'privacy_consents es de solo inserción: un cambio se registra con una fila nueva (ADR 0009)';
end $$;

create trigger consentimientos_sellados before insert on public.privacy_consents
  for each row execute function privado.sellar_consentimiento();
create trigger consentimientos_inmutables before update on public.privacy_consents
  for each row execute function privado.consentimiento_inmutable();

-- Privilegios: Supabase da por defecto todo a anon y authenticated en tablas nuevas; aquí se deja solo lo necesario.
alter table public.privacy_consents enable row level security;
revoke all on public.privacy_consents from public, anon, authenticated;
grant select, insert on public.privacy_consents to authenticated;

create policy consentimientos_lectura on public.privacy_consents
  for select to authenticated using (user_id = auth.uid());
create policy consentimientos_alta on public.privacy_consents
  for insert to authenticated with check (user_id = auth.uid());
-- Sin políticas de update ni delete.

-- ── 3. RPC aceptar_aviso_de_privacidad ──────────────────────────────────────────
-- Inserta el aviso y, solo si no estaba ya aceptado, una fila por cada una de las tres finalidades con `granted`
-- según su casilla (A-1). Devuelve true si registró y false si ya estaba aceptado (reintentar es seguro). Tras una
-- revocación (H-6) vuelve a registrar. Todo en una transacción. `security invoker` (no definer): RLS aplica y
-- CP-151a sigue en 0.
create or replace function public.aceptar_aviso_de_privacidad(
  p_version text,
  p_finalidades public.finalidad_secundaria[] default '{}'
) returns boolean
language plpgsql security invoker set search_path = public, pg_temp as $$
begin
  perform privado.bloquear_aviso(auth.uid(), p_version);
  if privado.aviso_vigente(auth.uid(), p_version) then
    return false;
  end if;

  -- El trigger exige la versión vigente (version_desactualizada) y sella usuario, fecha y método.
  insert into privacy_consents (user_id, notice_version, kind, granted)
  values (auth.uid(), p_version, 'aviso', true);

  insert into privacy_consents (user_id, notice_version, kind, purpose, granted)
  select auth.uid(), p_version, 'finalidad_secundaria', f, f = any(coalesce(p_finalidades, '{}'))
  from unnest(enum_range(null::public.finalidad_secundaria)) as f;

  return true;
end $$;

-- H-6 · «No acepto» con un consentimiento ya guardado: registra la revocación como fila nueva del aviso con
-- `granted = false` (la tabla es de solo inserción). Solo para auth.uid(): no recibe usuario. Si el aviso no estaba
-- aceptado no inserta nada y devuelve false (CA-9; reintentar es seguro). `security invoker`: RLS aplica.
create or replace function public.revocar_aviso_de_privacidad(p_version text) returns boolean
language plpgsql security invoker set search_path = public, pg_temp as $$
begin
  perform privado.bloquear_aviso(auth.uid(), p_version);
  if not privado.aviso_vigente(auth.uid(), p_version) then
    return false;
  end if;

  insert into privacy_consents (user_id, notice_version, kind, granted)
  values (auth.uid(), p_version, 'aviso', false);

  return true;
end $$;

-- H-6 · ¿El usuario de la sesión tiene aceptada esa versión del aviso? Respeta la revocación (fila más reciente).
create or replace function public.aviso_de_privacidad_aceptado(p_version text) returns boolean
language sql stable security invoker set search_path = public, pg_temp as $$
  select privado.aviso_vigente(auth.uid(), p_version);
$$;

-- ── 4. AT-18 (a): community_id inmutable para el usuario ────────────────────────
-- Un trigger y no `revoke update (community_id)`, porque un `grant update` de tabla completa futuro lo reabriría.
-- service_role y las funciones `security definer` de C-03 (corren como su dueño) sí pueden cambiarlo.
create or replace function privado.comunidad_inmutable() returns trigger
language plpgsql set search_path = public, pg_temp as $$
begin
  if new.community_id is distinct from old.community_id and current_user in ('authenticated', 'anon') then
    raise exception 'community_id no se cambia desde la app: lo asigna el alta aprobada por el Director (AT-18)'
      using errcode = '42501';
  end if;
  return new;
end $$;

create trigger perfiles_comunidad_inmutable before update of community_id on public.profiles
  for each row execute function privado.comunidad_inmutable();

-- ── Permisos de las funciones nuevas ────────────────────────────────────────────
-- El `grant … on all functions` de la migración 4 no cubre funciones creadas después.
revoke all on function privado.version_vigente_del_aviso() from public, anon;
revoke all on function privado.sellar_consentimiento() from public, anon;
revoke all on function privado.consentimiento_inmutable() from public, anon;
revoke all on function privado.comunidad_inmutable() from public, anon;
revoke all on function privado.aviso_vigente(uuid, text) from public, anon;
revoke all on function privado.bloquear_aviso(uuid, text) from public, anon;
grant execute on function privado.version_vigente_del_aviso() to authenticated;
grant execute on function privado.sellar_consentimiento() to authenticated;
grant execute on function privado.consentimiento_inmutable() to authenticated;
grant execute on function privado.comunidad_inmutable() to authenticated;
grant execute on function privado.aviso_vigente(uuid, text) to authenticated;
grant execute on function privado.bloquear_aviso(uuid, text) to authenticated;

revoke all on function public.aceptar_aviso_de_privacidad(text, public.finalidad_secundaria[]) from public, anon;
grant execute on function public.aceptar_aviso_de_privacidad(text, public.finalidad_secundaria[]) to authenticated;
revoke all on function public.revocar_aviso_de_privacidad(text) from public, anon;
grant execute on function public.revocar_aviso_de_privacidad(text) to authenticated;
revoke all on function public.aviso_de_privacidad_aceptado(text) from public, anon;
grant execute on function public.aviso_de_privacidad_aceptado(text) to authenticated;
