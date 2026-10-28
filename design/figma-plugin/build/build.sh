#!/usr/bin/env bash
# Genera el plugin listo para importar en Figma y lo prueba contra el simulador.
set -euo pipefail
cd "$(dirname "$0")"
python3 flows.py
OUT=../dist
rm -rf "$OUT" && mkdir -p "$OUT"
cat ../data.js engine.js > "$OUT/code.js"
cp manifest.json ui.html LEEME.md "$OUT/"
node --check "$OUT/code.js"
node -e '
const { figma, stats } = require("./mock-figma.js");
require(process.argv[1]);
const wait = () => new Promise((r) => setTimeout(r, 50));
(async () => {
  for (let i = 0; i < 400 && !global.__done && !process.exitCode; i++) await wait();
  if (!global.__done) { console.error("No terminó"); process.exit(1); }
  console.log("Páginas:", figma.root.children.map((p) => p.name).join(" | "));
  console.log("Estadísticas:", JSON.stringify(stats));
  const links = JSON.parse(global.__done.links);
  console.log("Historias con enlace profundo:", Object.keys(links).length);
})();
' "$(cd "$OUT" && pwd)/code.js"
