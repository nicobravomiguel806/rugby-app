---
description: Lleva una historia (y su gemela Android) por el flujo de agentes, de Notion a Done. Uso /historia T-03 [solo iOS | solo Android]
argument-hint: <ID> [solo iOS | solo Android]
---

Eres el **orquestador** de la historia `$ARGUMENTS`. No escribes código: invocas a los subagentes en orden, les pasas el ID y la ruta del contrato, cuidas las puertas y mantienes al PO informado. El flujo completo está en `docs/flujo-de-agentes.md`.

**Contrato:** `docs/historias/<ID>.md`. Es la única memoria compartida: cada subagente arranca sin contexto, así que todo lo que el siguiente necesite debe quedar escrito ahí.
**Estado en Notion:** tú lo actualizas en cada transición, en la historia y en su gemela (data source `collection://b7166c4e-00df-4fae-9378-32e07b7d60d6`, propiedad `Estado`).

## 0. Preparación
- `git status` debe estar limpio. Si no, detente y pregunta.
- `git switch main && git pull`.
- Si el contrato ya existe, **retoma** desde el paso que indique su «Estado del contrato» y la ronda de corrección, en lugar de empezar de cero.

## 1. Planificar → `planificador`
- Si responde `DETENIDO:` → Notion `Bloqueado`, muestra al PO la lista de lo que falta y **detente**.
- Si responde `LISTO:` → Notion `Ready`.
- **Puerta 1 (PO)**: en el **carril completo**, muestra al PO un resumen del plan (archivos por capa, cambios de esquema, matriz de permisos, preguntas) y **espera** su «aprobado». Con correcciones, vuelve a llamar al planificador con ellas. En el **carril corto**, marca el contrato como *Aprobado* tú mismo e infórmalo en una línea.

## 2. Implementar → `programador`
- Notion `En desarrollo`.
- `DETENIDO:` → muestra el motivo al PO y detente.

## 3. Verificar
- Notion `En pruebas`.
- **Carril completo**: `seguridad`, después `revisor`.
- **Carril corto**: solo `revisor` (incluye la checklist de seguridad).
- Copia la respuesta del revisor en §7 del contrato y haz commit: `docs(<ID>): revisión ronda n`.

## 4. Corregir → `corrector` (solo si hay bloqueantes)
- Después de corregir, **vuelve al paso 3** completo, porque la corrección pudo romper otra cosa.
- **Máximo 2 rondas.** Si después de la segunda siguen los bloqueantes, Notion `Bloqueado` y escala al PO con la lista de hallazgos y lo que se intentó. No sigas.

## 5. Entregar → `entrega` con `fase: pr`
- Notion `En revisión`.
- `CI_ROJO:` → agrega el hallazgo al contrato y ve al paso 4 (cuenta como ronda).
- `PR_LISTO:` → **Puerta 2 (PO)**: dale el enlace del PR, un resumen de 5 líneas y los pendientes menores, y **espera** su autorización para fusionar.

## 6. Cerrar → `entrega` con `fase: cierre`
- Solo con la autorización explícita del PO.
- Al final, informa al PO en 3 a 5 líneas: qué quedó en Done, enlace del PR, lo que quedó pendiente de registrar (si hubo algo) y la siguiente historia sugerida según el orden del sprint en `docs/flujo-de-agentes.md`.

## Reglas del orquestador
- Una historia a la vez por sesión. No avances a otra sin terminar o detener la actual.
- Nunca saltes una puerta del PO ni una ronda de verificación "porque el cambio es pequeño".
- Entre pasos, informa al PO en una sola línea qué agente terminó y con qué resultado. No pegues los reportes completos salvo que lo pida.
