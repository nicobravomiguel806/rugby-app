-- T-02 / SP-03 · Esquema base (MER del Sprint 1: 22 tablas + vista standings)
-- Cambios respecto al MER: match_events agrega device_seq y server_ts (RNF-13, SP-02).

create extension if not exists pgcrypto;

-- ── Tipos ───────────────────────────────────────────────────────────────────────
create type public.tipo_perfil as enum ('fan','jugador','entrenador','manager','medico','arbitro','padre');
create type public.rol_admin as enum ('masteruser','director');
create type public.modalidad as enum ('7','10','13','15','festival');
create type public.etapa_partido as enum ('pre','live','post','closed');
create type public.estado_solicitud as enum ('pendiente','aprobada','rechazada');
create type public.rol_en_equipo as enum ('jugador','entrenador','manager','medico');
create type public.rol_oficial as enum ('arbitro','anotador','juez_de_linea');
create type public.tipo_evento as enum ('ensayo','conversion','penal','drop','ensayo_de_penal',
                                        'tarjeta_amarilla','tarjeta_roja','cambio','anulacion',
                                        'inicio','fin_de_tiempo','fin');
create type public.tipo_reporte as enum ('pre','post','medical','discipline');

-- ── Comunidad y perfiles ────────────────────────────────────────────────────────
create table public.communities (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  region text
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  community_id uuid not null references public.communities(id),
  full_name text not null check (length(full_name) between 2 and 120),
  birth_date date not null,
  photo_url text
);

create table public.profile_types (
  profile_id uuid references public.profiles(id) on delete cascade,
  type public.tipo_perfil,
  primary key (profile_id, type)
);

create table public.player_details (
  profile_id uuid primary key references public.profiles(id) on delete cascade,
  position text,
  height_cm int check (height_cm between 80 and 230),
  weight_kg int check (weight_kg between 15 and 200)
);

create table public.guardianships (
  guardian_id uuid references public.profiles(id) on delete cascade,
  minor_id uuid references public.profiles(id) on delete cascade,
  status public.estado_solicitud not null default 'pendiente',
  consent_at timestamptz,
  primary key (guardian_id, minor_id),
  check (guardian_id <> minor_id)
);

create table public.medical_records (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.profiles(id) on delete cascade,
  medic_id uuid not null references public.profiles(id),
  fitness_status text not null check (fitness_status in ('apto','apto_con_restricciones','no_apto')),
  injury text,
  recorded_at timestamptz not null default now()
);

create table public.admin_roles (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  community_id uuid not null references public.communities(id) on delete cascade,
  role public.rol_admin not null,
  unique (profile_id, community_id, role)
);

-- ── Equipos ─────────────────────────────────────────────────────────────────────
create table public.teams (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities(id),
  name text not null,
  crest_url text,
  category text
);

create table public.team_memberships (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  role public.rol_en_equipo not null,
  status public.estado_solicitud not null default 'pendiente',
  resolved_by uuid references public.profiles(id),
  unique (team_id, profile_id, role)
);

-- ── Torneos ─────────────────────────────────────────────────────────────────────
create table public.tournaments (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities(id),
  name text not null,
  modality public.modalidad not null,
  category text,
  status text not null default 'borrador' check (status in ('borrador','inscripcion','en_curso','finalizado'))
);

create table public.tournament_rules (
  tournament_id uuid primary key references public.tournaments(id) on delete cascade,
  pts_win int not null default 4,
  pts_draw int not null default 2,
  pts_loss int not null default 0,
  bonus_try int not null default 4,
  bonus_loss_margin int not null default 7,
  half_minutes int not null,
  tiebreakers jsonb not null default '["puntos","diferencia","ensayos","enfrentamiento"]'
);

create table public.tournament_admins (
  tournament_id uuid references public.tournaments(id) on delete cascade,
  profile_id uuid references public.profiles(id) on delete cascade,
  primary key (tournament_id, profile_id)
);

create table public.tournament_teams (
  id uuid primary key default gen_random_uuid(),
  tournament_id uuid not null references public.tournaments(id) on delete cascade,
  team_id uuid not null references public.teams(id),
  pool text,
  unique (tournament_id, team_id)
);

create table public.tournament_rosters (
  id uuid primary key default gen_random_uuid(),
  tournament_team_id uuid not null references public.tournament_teams(id) on delete cascade,
  profile_id uuid not null references public.profiles(id),
  jersey_number int check (jersey_number between 1 and 99),
  eligible boolean not null default false,
  unique (tournament_team_id, profile_id)
);

-- ── Partido ─────────────────────────────────────────────────────────────────────
create table public.matches (
  id uuid primary key default gen_random_uuid(),
  tournament_id uuid not null references public.tournaments(id) on delete cascade,
  home_tt_id uuid not null references public.tournament_teams(id),
  away_tt_id uuid not null references public.tournament_teams(id),
  round int,
  scheduled_at timestamptz,
  stage public.etapa_partido not null default 'pre',
  check (home_tt_id <> away_tt_id)
);

create table public.match_officials (
  match_id uuid references public.matches(id) on delete cascade,
  profile_id uuid references public.profiles(id),
  role public.rol_oficial not null,
  primary key (match_id, profile_id)
);

create table public.match_lineups (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  roster_id uuid not null references public.tournament_rosters(id),
  jersey_number int not null,
  starter boolean not null default true,
  unique (match_id, roster_id)
);

create table public.match_events (
  id uuid primary key,                         -- UUID generado en el cliente (SP-02)
  match_id uuid not null references public.matches(id) on delete cascade,
  type public.tipo_evento not null,
  team_side text not null check (team_side in ('local','visita')),
  roster_id uuid references public.tournament_rosters(id),
  minute int not null check (minute between 0 and 200),
  period int not null default 1,
  points int not null default 0,
  voids_event_id uuid references public.match_events(id),
  created_by uuid not null references public.profiles(id),
  client_ts timestamptz not null,
  device_seq bigint not null,
  server_ts timestamptz not null default now(),
  check ((type = 'anulacion') = (voids_event_id is not null))
);
create index on public.match_events (match_id, device_seq);

create table public.match_reports (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  kind public.tipo_reporte not null,
  payload jsonb not null default '{}',
  pdf_url text,
  signed_by uuid references public.profiles(id)
);

-- ── Interacción ─────────────────────────────────────────────────────────────────
create table public.follows (
  follower_id uuid references public.profiles(id) on delete cascade,
  target_type text check (target_type in ('team','tournament','profile')),
  target_id uuid,
  primary key (follower_id, target_type, target_id)
);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  type text not null,
  payload jsonb not null default '{}',
  read_at timestamptz
);

create table public.posts (
  id uuid primary key default gen_random_uuid(),
  tournament_id uuid not null references public.tournaments(id) on delete cascade,
  author_id uuid not null references public.profiles(id),
  body text not null check (length(body) <= 2000),
  created_at timestamptz not null default now()
);

-- ── Vista de tabla de posiciones (se completa en M-01; aquí solo la forma) ──────
create view public.standings with (security_invoker = true) as
select m.tournament_id, tt.id as tournament_team_id,
       count(m.id) filter (where m.stage = 'closed') as played
from public.tournament_teams tt
left join public.matches m on tt.id in (m.home_tt_id, m.away_tt_id)
group by m.tournament_id, tt.id;
