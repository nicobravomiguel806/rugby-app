#!/usr/bin/env bash
# SP-04 · H-2 / T-03 CA-2 (CP-111): la app tiene deployment target iOS 17.0, así que sus pruebas corren en un
# simulador con runtime iOS 17 aunque se compile con un Xcode actual. Si el runtime no está, lo descarga
# (xcodebuild -downloadPlatform); crea (o reutiliza) un iPhone 15 con ese runtime e imprime su destino:
#
#   IOS_DESTINATION="$(./ios/scripts/simulador-ios17.sh)" ./ios/scripts/build-app.sh
#
# Versión del runtime: IOS17_VERSION (17.5 por defecto). Todo lo que no es el destino va a stderr.
set -euo pipefail
VERSION="${IOS17_VERSION:-17.5}"
NOMBRE="RugbyApp iPhone 15 (iOS $VERSION)"
TIPO="com.apple.CoreSimulator.SimDeviceType.iPhone-15"

runtime() {
  xcrun simctl list runtimes -j | python3 -c '
import json, sys
version = sys.argv[1]
for r in json.load(sys.stdin)["runtimes"]:
    if r.get("platform") == "iOS" and r.get("isAvailable") and r["version"] == version:
        print(r["identifier"]); break
' "$VERSION"
}

RUNTIME="$(runtime)"
if [ -z "$RUNTIME" ]; then
  echo "▶ Descargando el runtime de iOS $VERSION" >&2
  # -buildVersion existe desde Xcode 16 (CI: Xcode 16.4 en macos-15, que no trae runtime iOS 17 preinstalado).
  if ! xcodebuild -downloadPlatform iOS -buildVersion "$VERSION" >&2; then
    echo "::error::No se pudo descargar el runtime de simulador iOS $VERSION (xcodebuild -downloadPlatform). CP-111 exige iOS 17: no se usa otro runtime." >&2
    exit 1
  fi
  RUNTIME="$(runtime)"
fi
if [ -z "$RUNTIME" ]; then
  echo "::error::No hay runtime de simulador iOS $VERSION disponible para este Xcode." >&2
  exit 1
fi

UDID="$(xcrun simctl list devices "$RUNTIME" available | grep -F "$NOMBRE (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/' || true)"
if [ -z "$UDID" ]; then
  UDID="$(xcrun simctl create "$NOMBRE" "$TIPO" "$RUNTIME")"
fi
echo "▶ Simulador $NOMBRE · $RUNTIME · $UDID" >&2
echo "platform=iOS Simulator,id=$UDID"
