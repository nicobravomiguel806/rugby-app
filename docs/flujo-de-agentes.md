# Flujo de agentes · Sprint 3 en adelante

Cada historia del backlog pasa por un equipo de agentes de Claude Code que se ejecutan en la Mac del PO. Se arranca con un solo comando:

```
/historia T-03            # historia + su gemela Android en la misma rama
/historia C-08 solo iOS   # si se quiere separar la gemela
```

Los agentes viven en `.claude/agents/`, el comando en `.claude/commands/historia.md` y los permisos en `.claude/settings.json`. Viajan con el repo: quien lo clone los tiene.

## Agentes

| # | Agente | Hace | Puede editar | Termina con |
|---|---|---|---|---|
| 1 | `planificador` | Lee Notion, Plan de Pruebas, `domain-model.md`, modelo de amenazas y Figma. Verifica la DoR y escribe el contrato: criterios, plan por capas, firmas espejo y diseño de RLS | Solo `docs/historias/` | `LISTO` o `DETENIDO` (falta algo o hay preguntas) |
| 2 | `programador` | Rama `feat/<ID>-…`, reglas en `domain-model.md`, tests primero, Domain → Data → Presentation, migración | Código | `verificar.sh` en verde + rama subida |
| 3 | `seguridad` | Audita contra el contrato, CLAUDE.md y `threat-model.md`. Escribe pruebas pgTAP que intentan romper los permisos | Solo `backend/supabase/tests/` | Hallazgos (`LIMPIO` / `BLOQUEANTES`) |
| 4 | `revisor` | CA por CA, bugs, casos límite, paridad iOS/Android, DoD. Corre todas las pruebas | **Nada** (solo lectura) | Veredicto + hallazgos |
| 5 | `corrector` | Por hallazgo: prueba que falla → corrección mínima → prueba en verde → suite completa | Código | Hallazgos corregidos. Máximo 2 rondas |
| 6 | `entrega` | Abre el PR y vigila el CI. Tras el OK del PO: merge, migraciones a Supabase dev, Notion, Plan de Pruebas, Matriz y docs | Docs y Notion | `PR_LISTO` / `ENTREGADO` |

La sesión principal de Claude Code es el **orquestador**: llama a los agentes en orden, cuida las puertas y mueve el `Estado` en Notion.

## Flujo

```
/historia <ID>
   │
   ▼
[1 planificador] ── DETENIDO ──► PO responde preguntas
   │ LISTO (Notion: Ready)
   ▼
 ◆ Puerta 1: PO aprueba el plan  (solo carril completo)
   │
   ▼
[2 programador]  (Notion: En desarrollo)
   │
   ▼
[3 seguridad]* ──► [4 revisor]  (Notion: En pruebas)        * solo carril completo
   │ con bloqueantes                    │ limpio
   ▼                                    ▼
[5 corrector] ──► vuelve a 3      [6 entrega · PR]  (Notion: En revisión)
 (máx. 2 rondas; luego escala)         │ CI rojo → corrector
                                       ▼ CI verde
                                ◆ Puerta 2: PO autoriza el merge
                                       │
                                       ▼
                                [6 entrega · cierre] → main, Supabase dev, Notion Done, Sheets, docs
```

## Carriles
- **Completo**: la historia base vale 5 puntos o más, **o** toca migraciones, RLS o funciones SQL. Pasa por los 6 agentes y las 2 puertas.
- **Corto**: 3 puntos o menos y sin cambios de esquema. Pasa por planificador → programador → revisor (con la checklist de seguridad) → [corrector] → entrega. No hay Puerta 1; la Puerta 2 sí.

## Reglas de congruencia
1. **El contrato `docs/historias/<ID>.md` es la única memoria compartida.** Cada agente arranca en frío y escribe solo su sección. Lo que no está en el contrato no existe.
2. **Un solo agente escribe código de producción a la vez**: el programador y, después, el corrector. Seguridad y revisión reportan; no arreglan.
3. **Nadie inventa reglas de negocio.** Si no están en `domain-model.md` ni en Notion, el planificador pregunta y el flujo se detiene.
4. **"Verde" significa que `./scripts/verificar.sh` corrió y pasó.** Si falta una herramienta, cuenta como rojo.
5. **Las gemelas van juntas**: misma rama, mismo contrato y el mismo CP-xxx en Swift y Kotlin.
6. **Una historia a la vez.** El paralelismo con worktrees se evalúa cuando el flujo ya haya corrido varias historias sin incidentes.

## Puertas y protecciones
| Qué | Cómo se hace cumplir |
|---|---|
| Nada llega a `main` sin PR y CI verde | Protección de rama en GitHub: 6 checks requeridos, sin bypass, solo squash |
| El PO aprueba el plan (carril completo) y el merge | El orquestador se detiene. `gh pr merge` está en `ask` en `.claude/settings.json`: Claude Code pide confirmación |
| Nadie sube directo a main ni hace force push | `deny` en `.claude/settings.json` + protección de rama |
| Migraciones a la nube solo en dev y con confirmación | `supabase db push` en `ask`. No existe proyecto de producción todavía (T-02) |
| Los agentes no leen secretos locales | `deny` de lectura para `.env*` y `Secrets.xcconfig` |

## Verificación local
`./scripts/verificar.sh` corre en la Mac los mismos checks que el CI, solo para las carpetas que cambiaron: architecture-guard, gitleaks, migraciones + RLS, `swift test`, `gradle :domain:test` y, cuando existan, `ios/scripts/build-app.sh` y `android/scripts/build-app.sh` (los crean T-03 y AN-T-03).

Herramientas necesarias en la Mac: Xcode 15.4+, `brew install gitleaks postgresql@16 gradle gh xcodegen supabase/tap/supabase`, Docker Desktop u OrbStack (para `supabase start`), JDK 17 y Android Studio. XcodeGen genera el proyecto de Xcode (ADR 0004). El Android SDK se encuentra con `ANDROID_HOME` o con `android/local.properties` (`sdk.dir=…`, ignorado por git); si el shell no exporta `ANDROID_HOME`, crea ese archivo.

## Modo local (mientras GitHub está suspendido)
> **Terminó el 2026-11-12:** GitHub volvió. Se conserva como registro y por si se repite una suspensión. Lo que sigue vigente es la regla 6 y la sección «Uso de GitHub».

Rigió del 2026-11-11 al 2026-11-12, por decisión del PO:
1. **Sin GitHub.** No se hace `git push`, no se usa `gh` y no se cambia el remoto.
2. **Historias apiladas.** Cada historia nueva sale de la rama de la anterior: C-02 desde `feat/C-01-registro-de-usuario`, y así. No se fusiona nada a `main` local.
3. **Mismo flujo de agentes:** planificador → programador → seguridad → revisor → corrector. En lugar del CI, la verificación final es `./scripts/verificar.sh --todo` en verde.
4. **La entrega corre en `fase: local`.**
   - Deja el contrato en «Listo para PR».
   - Guarda el cuerpo del PR en `docs/historias/<ID>-pr.md`.
   - Pasa la historia y su gemela a «En revisión» en Notion, con la nota «pendiente GitHub».
   - **No** registra Done ni marca el Plan de Pruebas como ejecutado en CI.
   - La Puerta 2 (merge) se hace cuando vuelva GitHub, con CI real.
5. **Máximo 4 historias apiladas.** Al llegar a 4, el orquestador avisa al PO y no empieza otra.
6. **Al volver GitHub:** se abre un PR por historia, en orden. Después de cada squash merge, la siguiente rama se rebasa sobre `main` antes de abrir su PR.

## Uso de GitHub (para evitar otra suspensión)
Desde el 2026-11-12, por decisión del PO, después de la suspensión de la cuenta. Aplican al orquestador y a todos los agentes:
1. **Máximo 1 reintento del CI** por ejecución fallida. Si no hay runners de macOS, se espera; nunca se relanza en bucle.
2. **Vigilar el CI con intervalos de 60 s o más** (`gh run watch --interval 60`). Nunca sondeo continuo.
3. **Push solo al abrir el PR y una vez por ronda de corrección**, no por cada commit.
4. **Un PR a la vez.** Las historias apiladas se entregan en orden: se espera el CI y el merge de cada una antes de abrir el PR de la siguiente.
5. **Solo la cuenta `nicobravomiguel806`.** Comprueba `gh auth status` antes de usar `gh` o hacer push.

## Orden del Sprint 3 (corte en S5)
Mitad del MVP: S0 a S5 suman **157 de 302 puntos**. Ya están en Done 12 (SP-01, SP-02, SP-03 y T-01). Quedan **145**.

| Orden | Historia(s) | Pts (con gemela) | Notas |
|---|---|---|---|
| 1 | T-03 + AN-T-03 · esqueletos de las apps | 10 | Primera prueba del flujo. Debe dejar `ios/scripts/build-app.sh`, `android/scripts/build-app.sh`, el wrapper de Gradle y los jobs `ios-app` / `android-app` en el CI. Requiere un ADR para generar el proyecto de Xcode |
| 2 | SP-04 · auth nativa | 2 | Necesita cuenta de Apple Developer y cliente OAuth de Google |
| 3 | C-01, C-02, C-03 (+AN) | 26 | Cuentas y perfiles |
| 4 | C-04, C-05, E-01 (+AN) | 22 | C-05 toca datos de menores (AT-01) |
| 5 | C-08, E-02, E-03, A-01 (+AN) | 32 | |
| 6 | **A-03** · permisos en datos | 5 | Antes de A-02 y O-01 |
| 7 | A-02, O-01 (+AN) | 16 | |
| 8 | O-02, O-03, O-04 (+AN) | 26 | O-02 usa el motor de reglas de SP-01 |

Pendientes de S0 que no son código: el proyecto de Supabase **prod** (T-02) se crea con la primera entrega, y el job `ios-app` del CI (T-04) llega con T-03.
