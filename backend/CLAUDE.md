# backend/ · Supabase

- Migraciones en `supabase/migrations/AAAAMMDDhhmmss_descripcion.sql`. Nunca edites una migración ya fusionada: crea otra.
- Toda tabla nueva: `enable row level security` + políticas + prueba en `supabase/tests/`.
- Funciones `security definer` siempre con `set search_path = public, pg_temp`.
- `match_events` es de solo inserción (trigger `eventos_inmutables`).
- Pruebas: `./scripts/run-db-tests.sh` (PostgreSQL local) o `supabase start && supabase db reset`.
- `service_role` solo en CI y Edge Functions; jamás en la app.
