#!/usr/bin/env bash
# Regla de dependencias (CP-001 / CP-100): Domain no importa frameworks de UI, persistencia ni Supabase,
# Presentation no conoce Data, y las dos plataformas tienen las mismas capas y los mismos casos de uso.
# Lo usan el CI (job architecture-guard) y ./scripts/verificar.sh, para que local y CI revisen lo mismo.
set -euo pipefail
cd "$(dirname "$0")/.."

fallo=0

# 1. Domain es puro (CP-001)
if [ -d ios/Packages/Domain/Sources ] && grep -rEn '^import (SwiftUI|UIKit|Supabase|SwiftData|Combine)' ios/Packages/Domain/Sources; then
  echo "::error::Domain de iOS importa un framework prohibido"; fallo=1
fi
if [ -d android/domain/src/main ] && grep -rEn '^import (android\.|androidx\.|io\.github\.jan\.supabase|io\.ktor)' android/domain/src/main; then
  echo "::error::Domain de Android importa un framework prohibido"; fallo=1
fi

# 2. Presentation → Domain, nunca → Data (T-03 / AN-T-03)
if [ -d ios/Packages/Presentation/Sources ] && grep -rEn '^import (Data|Supabase)$' ios/Packages/Presentation/Sources; then
  echo "::error::Presentation de iOS importa Data o Supabase"; fallo=1
fi
if [ -d android/presentation/src/main ] && grep -rEn '^import mx\.rugbyapp\.data(\.|$)' android/presentation/src/main; then
  echo "::error:::presentation de Android importa mx.rugbyapp.data"; fallo=1
fi

# 3. Paridad de estructura (CP-100): mismas capas y mismos *UseCase en las dos plataformas
for capa in Domain Data Presentation; do
  modulo="$(printf '%s' "$capa" | tr '[:upper:]' '[:lower:]')"
  if [ ! -d "ios/Packages/$capa" ] || [ ! -d "android/$modulo" ]; then
    echo "::error::Paridad: falta la capa $capa (ios/Packages/$capa ↔ android/$modulo)"; fallo=1
  fi
done
casos() { [ -d "$1" ] && find "$1" -name "*UseCase.$2" -exec basename {} ".$2" \; | sort -u || true; }
CASOS_IOS="$(casos ios/Packages/Domain/Sources swift)"
CASOS_AND="$(casos android/domain/src/main kt)"
for c in $(comm -23 <(printf '%s\n' "$CASOS_IOS") <(printf '%s\n' "$CASOS_AND")); do
  echo "::error::Paridad: $c.swift no tiene gemelo $c.kt en android/domain"; fallo=1
done
for c in $(comm -13 <(printf '%s\n' "$CASOS_IOS") <(printf '%s\n' "$CASOS_AND")); do
  echo "::error::Paridad: $c.kt no tiene gemelo $c.swift en ios/Packages/Domain"; fallo=1
done

[ "$fallo" -eq 0 ] && echo "Regla de dependencias y paridad iOS/Android respetadas"
exit "$fallo"
