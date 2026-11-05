#!/usr/bin/env bash
# Corre en local los mismos checks que el CI, solo para las carpetas que cambiaron respecto a main.
#
#   ./scripts/verificar.sh          lo que cambió en esta rama (incluye cambios sin commit)
#   ./scripts/verificar.sh --todo   todo, sin importar qué cambió
#
# Sale con 0 solo si todo pasó. Si falta una herramienta para un área que cambió, cuenta como falla:
# un agente no puede reportar "verde" sin haber corrido la prueba.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BASE="${BASE:-origin/main}"
if [ "${1:-}" = "--todo" ]; then
  CAMBIOS="$(printf '%s\n' backend/ ios/ android/)"
else
  git fetch -q origin main 2>/dev/null || true
  DESDE="$(git merge-base HEAD "$BASE" 2>/dev/null || echo HEAD)"
  CAMBIOS="$( { git diff --name-only "$DESDE"; git diff --name-only; git ls-files --others --exclude-standard; } | sort -u )"
fi
cambio() { printf '%s\n' "$CAMBIOS" | grep -q "^$1"; }

RESUMEN=(); FALLAS=0
paso() { # paso "nombre" comando...
  local nombre="$1"; shift
  echo; echo "━━ $nombre"
  if "$@"; then RESUMEN+=("✅ $nombre"); else RESUMEN+=("❌ $nombre"); FALLAS=$((FALLAS + 1)); fi
}
omitir() { RESUMEN+=("➖ $1 (sin cambios)"); }
falta() { RESUMEN+=("❌ $1: falta $2 · instala con: $3"); FALLAS=$((FALLAS + 1)); }

# 1. Siempre
paso "architecture-guard" ./scripts/architecture-guard.sh
if command -v gitleaks >/dev/null; then
  paso "secrets-scan (gitleaks)" gitleaks git --redact --exit-code 1 .
else
  falta "secrets-scan" gitleaks "brew install gitleaks"
fi

# 2. Backend
if cambio backend/; then
  if command -v pg_ctl >/dev/null || ls -d /usr/lib/postgresql/*/bin >/dev/null 2>&1 || [ -n "${PGBIN:-}" ]; then
    paso "backend (migraciones + RLS)" ./backend/scripts/run-db-tests.sh
  else
    falta "backend" "PostgreSQL 15+" "brew install postgresql@16 && brew link postgresql@16 --force"
  fi
else omitir "backend"; fi

# 3. iOS
if cambio ios/; then
  if command -v swift >/dev/null; then
    paso "ios-domain (swift test)" bash -c "cd ios/Packages/Domain && swift test"
  else
    falta "ios-domain" "Swift" "instalar Xcode 15.4+ desde la App Store"
  fi
  if [ -x ios/scripts/build-app.sh ]; then
    paso "ios-app (build + tests en simulador)" ./ios/scripts/build-app.sh
  else
    RESUMEN+=("➖ ios-app (aún no existe ios/scripts/build-app.sh; lo crea T-03)")
  fi
else omitir "ios"; fi

# 4. Android
if cambio android/; then
  GRADLE=""; [ -x android/gradlew ] && GRADLE="./gradlew"; [ -z "$GRADLE" ] && command -v gradle >/dev/null && GRADLE="gradle"
  if [ -n "$GRADLE" ]; then
    paso "android-domain (:domain:test)" bash -c "cd android && $GRADLE :domain:test --console=plain"
  else
    falta "android-domain" "Gradle o android/gradlew" "brew install gradle (AN-T-03 agrega el wrapper)"
  fi
  if [ -x android/scripts/build-app.sh ]; then
    paso "android-app (assembleDebug + tests)" ./android/scripts/build-app.sh
  else
    RESUMEN+=("➖ android-app (aún no existe android/scripts/build-app.sh; lo crea AN-T-03)")
  fi
else omitir "android"; fi

echo; echo "━━━━━━━━ Resumen ━━━━━━━━"
printf '%s\n' "${RESUMEN[@]}"
if [ "$FALLAS" -eq 0 ]; then echo "Todo en verde."; else echo "$FALLAS paso(s) en rojo."; fi
[ "$FALLAS" -eq 0 ]
