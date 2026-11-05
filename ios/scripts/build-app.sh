#!/usr/bin/env bash
# Compila la app de iOS y corre sus pruebas (T-03 · CA-2 / CP-111). Lo usan ./scripts/verificar.sh y el job ios-app.
#
#   ./ios/scripts/build-app.sh
#   IOS_DESTINATION='platform=iOS Simulator,name=iPhone 15' ./ios/scripts/build-app.sh
#
# Si no se define IOS_DESTINATION, usa el primer simulador de iPhone disponible.
set -euo pipefail
IOS="$(cd "$(dirname "$0")/.." && pwd)"
cd "$IOS"

if ! command -v xcodegen >/dev/null; then
  echo "::error::Falta xcodegen (ADR 0004). Instálalo con: brew install xcodegen" >&2
  exit 1
fi

echo "▶ xcodegen generate"
xcodegen generate --spec project.yml --quiet

# H-10: el CI compila con Xcode 15.4, que abre hasta objectVersion 63 (formato Xcode 15.3).
OBJ_VERSION="$(sed -nE 's/^[[:space:]]*objectVersion = ([0-9]+);/\1/p' RugbyApp.xcodeproj/project.pbxproj)"
if [ -z "$OBJ_VERSION" ] || [ "$OBJ_VERSION" -gt 63 ]; then
  echo "::error::RugbyApp.xcodeproj tiene objectVersion ${OBJ_VERSION:-?}; Xcode 15.4 solo abre hasta 63. Fija options.projectFormat en ios/project.yml." >&2
  exit 1
fi

echo "▶ swift test (Packages/Data)"
(cd Packages/Data && swift test)

if [ -z "${IOS_DESTINATION:-}" ]; then
  UDID="$(xcrun simctl list devices available | grep -E '^[[:space:]]+iPhone' | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')"
  if [ -z "$UDID" ]; then
    echo "::error::No hay simuladores de iPhone disponibles. Define IOS_DESTINATION o instala uno en Xcode." >&2
    exit 1
  fi
  IOS_DESTINATION="platform=iOS Simulator,id=$UDID"
fi
echo "▶ xcodebuild build test · $IOS_DESTINATION"

xcodebuild \
  -project RugbyApp.xcodeproj \
  -scheme RugbyApp \
  -destination "$IOS_DESTINATION" \
  -derivedDataPath "$IOS/build/DerivedData" \
  CODE_SIGNING_ALLOWED=NO \
  build test
