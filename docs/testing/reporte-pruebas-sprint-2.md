# Reporte de pruebas · Sprint 2

**Fecha de ejecución:** 28 de octubre de 2026 · **Commit:** etiqueta `v0.2.0` · **Alcance:** SPIKE SP-01, SP-02 y SP-03

## Resumen

| Suite | Herramienta | Casos | Pasan | Fallan | Estado |
|---|---|---|---|---|---|
| Dominio Android · motor de reglas (SP-01) | JUnit 4 · Kotlin 2.0 | 10 | 10 | 0 | ✅ |
| Dominio Android · cola offline (SP-02) | JUnit 4 · Kotlin 2.0 | 7 | 7 | 0 | ✅ |
| Base de datos · RLS y sync (SP-02, SP-03) | PostgreSQL 16 · aserciones TAP | 36 | 36 | 0 | ✅ |
| Arquitectura · Domain sin frameworks | architecture-guard (CI) | 2 | 2 | 0 | ✅ |
| Secretos en el repositorio | escaneo de patrones / gitleaks (CI) | 1 | 1 | 0 | ✅ |
| Dominio iOS · reglas + cola (espejo) | XCTest · Swift 5.10 | 17 | — | — | ⏳ se ejecuta en el job `ios-domain` (macOS) |
| **Total ejecutado** | | **56** | **56** | **0** | **100%** |

Los 17 casos de iOS son los mismos que los de Android (mismo CP-xxx). Quedan pendientes de ejecución porque requieren macOS/Xcode; se corren en el primer push del repositorio a GitHub.

## Detalle por caso

| Caso | Descripción | Suite | Resultado |
|---|---|---|---|
| CP-120 | Un ensayo vale 5 en XV y en 7s | Kotlin | ✅ |
| CP-121 | Rugby 13: ensayo 4 y drop 1 | Kotlin | ✅ |
| CP-122 | Conversión solo después de un ensayo del mismo equipo | Kotlin | ✅ |
| CP-123 | Con tarjeta roja el equipo juega con 14 | Kotlin | ✅ |
| CP-124 | Amarilla: 2 min en 7s, 10 min en XV | Kotlin | ✅ |
| CP-125 | Un jugador expulsado no puede anotar | Kotlin | ✅ |
| CP-126 | Un evento anulado no suma pero se conserva | Kotlin | ✅ |
| CP-127 | Festivales sin marcador; rugby 13 sin ensayo de penal | Kotlin | ✅ |
| CP-128 | Límite de cambios por modalidad | Kotlin | ✅ |
| CP-130 | Sin red el evento se guarda y no se pierde | Kotlin | ✅ |
| CP-131 | Al reconectar, los eventos llegan una sola vez | Kotlin | ✅ |
| CP-132 | Si se pierde la respuesta, el reintento no duplica | Kotlin | ✅ |
| CP-133 | Se envían en el orden de captura en varios lotes | Kotlin | ✅ |
| CP-134 | Encolar dos veces el mismo id no duplica | Kotlin | ✅ |
| CP-135 | Backoff 1, 2, 4… con tope de 60 s | Kotlin | ✅ |
| CP-140 (a–e) | Visibilidad de menores por rol | PostgreSQL | ✅ 5/5 |
| CP-141 (a–e) | Lectura de datos médicos por rol | PostgreSQL | ✅ 5/5 |
| CP-142 (a–c) | Alta de datos médicos solo por el médico del equipo | PostgreSQL | ✅ 3/3 |
| CP-143 (a–d) | Escalada de privilegios bloqueada | PostgreSQL | ✅ 4/4 |
| CP-144 (a–c) | Torneos solo por Directores de su comunidad | PostgreSQL | ✅ 3/3 |
| CP-145 (a–c) | Tutela validada por un administrador | PostgreSQL | ✅ 3/3 |
| CP-146 (a–e) | Sincronización idempotente y autor asignado por el servidor | PostgreSQL | ✅ 5/5 |
| CP-147 (a–c) | Solo oficiales, solo en vivo, lotes ≤ 200 | PostgreSQL | ✅ 3/3 |
| CP-148 (a–b) | Eventos inmutables | PostgreSQL | ✅ 2/2 |
| CP-149 | Sin sesión no se lee nada | PostgreSQL | ✅ |
| CP-150 (a–b) | 22 tablas, todas con RLS | PostgreSQL | ✅ 2/2 |

## Defectos
Ninguno abierto. Durante el desarrollo se corrigió la expresión del job `pr-convention`, que aceptaba títulos sin paréntesis de cierre (no llegó a `main`).

## Riesgos y siguientes pasos
1. Ejecutar la suite de iOS en CI al subir el repositorio.
2. Validar con el socio los valores marcados con * en `docs/domain-model.md` (10s, rugby 13, festivales).
3. Medir < 300 ms por evento en dispositivo real (RNF-06) cuando exista el almacén local (T-05).

## Cómo reproducir
```bash
./android/scripts/run-domain-tests.sh     # 17 casos Kotlin
./backend/scripts/run-db-tests.sh         # 36 aserciones PostgreSQL
cd ios/Packages/Domain && swift test      # 17 casos Swift (macOS)
```
