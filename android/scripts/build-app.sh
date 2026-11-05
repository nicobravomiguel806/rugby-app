#!/usr/bin/env bash
# Compila la app de Android y corre sus pruebas (AN-T-03 · CA-6 / CA-7 / CP-111).
# Lo usan ./scripts/verificar.sh y el job android-app del CI.
#
# Necesita el Android SDK en ANDROID_HOME (o ANDROID_SDK_ROOT) o en android/local.properties (sdk.dir).
# Si hay un emulador o dispositivo conectado, también corre la prueba instrumentada.
set -euo pipefail
ANDROID_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ANDROID_DIR"

# Java 17, el mismo del CI (Kotlin 2.0 no reconoce los JDK más recientes).
if [ "$(uname)" = "Darwin" ] && J17="$(/usr/libexec/java_home -v 17 2>/dev/null)"; then
  export JAVA_HOME="$J17"
fi

SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
if [ -z "$SDK" ] && [ -f local.properties ]; then
  SDK="$(sed -n 's/^sdk\.dir=//p' local.properties | tail -1)"
fi
if [ -z "$SDK" ] || [ ! -d "$SDK" ]; then
  echo "::error::No encuentro el Android SDK. Exporta ANDROID_HOME o crea android/local.properties con" >&2
  echo "        sdk.dir=/ruta/al/sdk (en macOS suele ser \$HOME/Library/Android/sdk). local.properties no se sube." >&2
  exit 1
fi
export ANDROID_HOME="$SDK"

echo "▶ Tests unitarios y assembleDebug (SDK: $SDK)"
./gradlew --console=plain \
  :domain:test :data:testDebugUnitTest :presentation:testDebugUnitTest :app:assembleDebug

ADB="$SDK/platform-tools/adb"
if [ -x "$ADB" ] && "$ADB" devices | awk 'NR > 1 && $2 == "device"' | grep -q .; then
  echo "▶ Prueba instrumentada en el dispositivo conectado"
  ./gradlew --console=plain :app:connectedDebugAndroidTest
else
  echo "➖ Sin emulador ni dispositivo conectado: se omite :app:connectedDebugAndroidTest (en el CI corre en API 29)"
fi
