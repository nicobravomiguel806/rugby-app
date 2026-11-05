#!/usr/bin/env bash
# Regla de dependencias (CP-001 / CP-100): Domain no importa frameworks de UI, persistencia ni Supabase.
# Lo usan el CI (job architecture-guard) y ./scripts/verificar.sh, para que local y CI revisen lo mismo.
set -euo pipefail
cd "$(dirname "$0")/.."

fallo=0
if [ -d ios/Packages/Domain/Sources ] && grep -rEn '^import (SwiftUI|UIKit|Supabase|SwiftData|Combine)' ios/Packages/Domain/Sources; then
  echo "::error::Domain de iOS importa un framework prohibido"; fallo=1
fi
if [ -d android/domain/src/main ] && grep -rEn '^import (android\.|androidx\.|io\.github\.jan\.supabase|io\.ktor)' android/domain/src/main; then
  echo "::error::Domain de Android importa un framework prohibido"; fallo=1
fi
[ "$fallo" -eq 0 ] && echo "Regla de dependencias respetada"
exit "$fallo"
