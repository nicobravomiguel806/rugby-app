# ADR 0001 · Motor de reglas en Domain con estado derivado de eventos

- **Estado:** Aceptada · 28 oct 2026 · SP-01
- **Contexto:** cinco modalidades con puntuación, tiempos, tarjetas y cambios distintos; la captura debe funcionar sin señal y ser auditable.
- **Decisión:** las reglas viven en `ReglasDeModalidad` (valores por defecto sobrescribibles por torneo) y el estado del partido se reconstruye con `MotorDePartido.calcular(eventos)`. El mismo motor existe en Swift y Kotlin con tests espejo.
- **Consecuencias:** (+) offline, probable, auditable, una sola fuente de reglas por plataforma. (−) dos implementaciones; se mitiga con los mismos casos CP-120 a CP-128 en ambas. El backend recalcula el resultado al cerrar el partido (R-01) para validar lo que envía la app.
