# SP-01 · Motor de reglas por modalidad

**Como** desarrollador **quiero** un motor de reglas por modalidad en Domain **para** que puntuación, tarjetas y cambios se validen igual en iOS, Android y backend.

## Pregunta
¿Cómo modelamos 7s, 10s, rugby 13, XV y festivales sin llenar las pantallas de `if modalidad == …`?

## Opciones evaluadas
| Opción | Ventaja | Desventaja |
|---|---|---|
| A. Reglas en el backend (función SQL) | Una sola implementación | No funciona sin señal (rompe RNF-01) |
| B. Reglas en cada View | Rápido de empezar | Duplicado, no probable, se desincroniza entre plataformas |
| **C. Tabla de reglas + motor que reconstruye el estado desde los eventos (event sourcing) en Domain** | Funciona offline, probable, auditable, mismo contrato en Swift y Kotlin | Se escribe dos veces (mitigado con tests espejo) |

## Decisión
Opción C. `ReglasDeModalidad.porDefecto(modalidad)` da los valores base, sobrescribibles por torneo (`tournament_rules`). `MotorDePartido.calcular(eventos, alMinuto)` reconstruye marcador, jugadores en cancha, expulsiones y cambios. Ver ADR 0001.

## Implementación
- Kotlin: `android/domain/src/main/kotlin/mx/rugbyapp/domain/rules/`
- Swift: `ios/Packages/Domain/Sources/Domain/Rules/`
- Reglas en lenguaje natural: `docs/domain-model.md §2`

## Criterios de aceptación
- **Diseño:** el motor vive en Domain, sin dependencias externas; los valores de cada modalidad están en un solo lugar.
- **Interfaz gráfica:** la pantalla de partido en vivo solo muestra los botones de anotación que existen en la modalidad (sin "ensayo de penal" en rugby 13, sin marcador en festivales).
- **Escenarios de prueba:** CP-120 a CP-128 pasan en Swift y en Kotlin.

## Resultado
10 tests de Kotlin en verde (CP-120 a CP-128 + modalidad desde código). Los mismos 10 casos están escritos en Swift y corren en el job `ios-domain` del CI.

## Pendiente para las historias
Validar con el socio los valores marcados con * en `docs/domain-model.md` (10s, rugby 13, festivales).
