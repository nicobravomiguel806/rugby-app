#!/usr/bin/env bash
# Levanta un PostgreSQL desechable, aplica las migraciones y corre las pruebas de seguridad (RLS) y sync.
# Uso local sin Docker:   ./backend/scripts/run-db-tests.sh
# En CI se usa `supabase start` + `supabase db reset` y luego este mismo archivo de pruebas con psql.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PGBIN="${PGBIN:-$(ls -d /usr/lib/postgresql/*/bin 2>/dev/null | sort -V | tail -1)}"
WORK="$(mktemp -d)"; PORT="${PORT:-54329}"
RUN_AS=""; [ "$(id -u)" = "0" ] && RUN_AS="runuser -u postgres --" && chown postgres "$WORK"

cleanup() { $RUN_AS "$PGBIN/pg_ctl" -D "$WORK/data" stop -m fast >/dev/null 2>&1 || true; rm -rf "$WORK"; }
trap cleanup EXIT

$RUN_AS "$PGBIN/initdb" -D "$WORK/data" -U postgres -A trust >/dev/null
$RUN_AS "$PGBIN/pg_ctl" -D "$WORK/data" -o "-p $PORT -k $WORK -c listen_addresses=''" -l "$WORK/log" start -w >/dev/null
PSQL=(psql -h "$WORK" -p "$PORT" -U postgres -d postgres -v ON_ERROR_STOP=1 -q)

"${PSQL[@]}" -f "$ROOT/supabase/tests/00_auth_stub.sql"
for m in "$ROOT"/supabase/migrations/*.sql; do echo "▶ Migración $(basename "$m")"; "${PSQL[@]}" -f "$m"; done

OUT="$WORK/out.txt"
"${PSQL[@]}" -f "$ROOT/supabase/tests/10_rls_y_sync.test.sql" 2>&1 | sed -n 's/^.*NOTICE:  //p' | tee "$OUT"
PASS=$(grep -c '^ok' "$OUT" || true); FAIL=$(grep -c '^not ok' "$OUT" || true)
echo "1..$((PASS + FAIL))"
echo "# Pruebas de base de datos: $PASS ok, $FAIL fallidas"
[ "$FAIL" -eq 0 ]
