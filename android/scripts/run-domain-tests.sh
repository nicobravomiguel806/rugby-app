#!/usr/bin/env bash
# Corre los tests del módulo :domain sin Android SDK ni red.
# En CI se usa ./gradlew :domain:test; este script sirve en máquinas sin acceso a Maven
# (usa el compilador de Kotlin y JUnit que ya trae la distribución de Gradle).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GRADLE_LIB="${GRADLE_LIB:-$(dirname "$(readlink -f "$(command -v gradle)")")/../lib}"
OUT="$ROOT/domain/build/manual"
rm -rf "$OUT" && mkdir -p "$OUT/main" "$OUT/test"

jar() { ls "$GRADLE_LIB"/$1-*.jar | head -1; }
STDLIB=$(jar kotlin-stdlib)
COMPILER_CP="$(jar kotlin-compiler-embeddable):$STDLIB:$(jar kotlin-script-runtime):$(jar kotlin-reflect):$(jar kotlinx-coroutines-core-jvm):$(jar kotlin-daemon-embeddable)"
for extra in trove4j annotations; do f=$(ls "$GRADLE_LIB"/$extra-*.jar 2>/dev/null | head -1 || true); [ -n "$f" ] && COMPILER_CP="$COMPILER_CP:$f"; done
JUNIT="$(jar junit):$(ls "$GRADLE_LIB"/hamcrest-core-*.jar "$GRADLE_LIB"/hamcrest-*.jar 2>/dev/null | head -1)"

kotlinc() { java -cp "$COMPILER_CP" org.jetbrains.kotlin.cli.jvm.K2JVMCompiler -no-stdlib -no-reflect -jvm-target 17 "$@"; }

echo "▶ Compilando domain/src/main"
kotlinc -cp "$STDLIB" -d "$OUT/main" $(find "$ROOT/domain/src/main" -name '*.kt')
echo "▶ Compilando domain/src/test"
kotlinc -cp "$STDLIB:$OUT/main:$JUNIT" -d "$OUT/test" $(find "$ROOT/domain/src/test" -name '*.kt')

CLASSES=$(cd "$OUT/test" && find . -name '*Test.class' | sed 's|^\./||; s|\.class$||; s|/|.|g' | sort)
echo "▶ Ejecutando: $CLASSES"
java -cp "$STDLIB:$OUT/main:$OUT/test:$JUNIT" org.junit.runner.JUnitCore $CLASSES
