#!/usr/bin/env bash
# SP-04 · H-2 (AT-16): la app fija TODAS sus dependencias de Swift (directas y transitivas) con Package.resolved
# versionados. Falla si falta alguno de los esperados o si no está versionado en git. Que esté al día respecto a
# los manifiestos lo comprueba build-app.sh al resolver solo con lo fijado (--force-resolved-versions en
# swift test, -onlyUsePackageVersionsFromResolvedFile en xcodebuild). No revisa swift-tools (decisión del PO).
set -euo pipefail
IOS="$(cd "$(dirname "$0")/.." && pwd)"
cd "$IOS"

ESPERADOS=(
  # swift test de Packages/Data (supabase-swift y sus transitivas).
  "Packages/Data/Package.resolved"
  # Proyecto de XcodeGen: el que usa xcodebuild para todo el grafo de la app (incluye GoogleSignIn-iOS).
  "RugbyApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
)

FALLAS=0
for archivo in "${ESPERADOS[@]}"; do
  if [ ! -s "$archivo" ]; then
    echo "::error::Falta ios/$archivo (AT-16). Genéralo con 'swift package resolve' o 'xcodebuild -resolvePackageDependencies' y versiónalo." >&2
    FALLAS=$((FALLAS + 1))
  elif git rev-parse --is-inside-work-tree >/dev/null 2>&1 && ! git ls-files --error-unmatch "$archivo" >/dev/null 2>&1; then
    echo "::error::ios/$archivo existe pero no está versionado en git (AT-16)." >&2
    FALLAS=$((FALLAS + 1))
  fi
done
[ "$FALLAS" -eq 0 ] && echo "✔ Package.resolved versionados: ${#ESPERADOS[@]}"
[ "$FALLAS" -eq 0 ]
