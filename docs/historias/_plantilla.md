# <ID> · <Título> (+ gemela <AN-ID> si aplica)

> Contrato de la historia. Es la **única memoria compartida** entre agentes: cada uno arranca sin contexto,
> lee este archivo y escribe **solo su sección**. Si algo no está aquí, para el siguiente agente no existe.

| Campo | Valor |
|---|---|
| Notion | <enlace a la historia> · gemela: <enlace o "—"> |
| Puntos · Plataforma · Sprint | <n> · <iOS/Android/Backend/Todas> · <Sx> |
| Carril | **Completo** (≥ 5 pts o toca esquema/RLS) · **Corto** (≤ 3 pts y sin esquema) |
| Rama | `feat/<ID>-<descripcion-corta>` |
| Estado del contrato | Borrador → Aprobado → Implementado → Revisado → Entregado |
| Ronda de corrección | 0 de 2 |

---

## 1. Historia · *Planificador*
**Como** … **quiero** … **para** …

**Criterios de aceptación** (copiados de Notion; numerados, porque los demás agentes los citan como CA-n):
- CA-1 …
- CA-2 …
- CA-3 …

**Casos de prueba** (del Plan de Pruebas): CP-xxx · descripción · dónde vivirá el test (Swift / Kotlin / pgTAP / manual).

**Depende de:** <historias que deben estar en Done> · **Diseño en Figma:** <enlace o "—">

## 2. Definition of Ready · *Planificador*
- [ ] ID, "Como… quiero… para…" y épica
- [ ] ≥ 3 criterios verificables
- [ ] ≤ 8 puntos
- [ ] En la Matriz y con ≥ 1 caso en el Plan de Pruebas
- [ ] Reglas de negocio en `docs/domain-model.md` (o propuestas abajo, en 3.4)
- [ ] Versión del story map asignada
- [ ] Dependencias en Done

## 3. Plan técnico · *Planificador*
### 3.1 Archivos por capa
| Capa | iOS | Android | Qué contiene |
|---|---|---|---|
| Domain | `ios/Packages/Domain/Sources/Domain/<Feature>/…` | `android/domain/src/main/kotlin/mx/rugbyapp/domain/<feature>/…` | entidades, casos de uso, protocolos |
| Data | … | … | repositorio, DTO, cliente |
| Presentation | … | … | ViewModel, View |
| Backend | `backend/supabase/migrations/<fecha>_<nombre>.sql` | (compartido) | tablas, RLS, funciones |

### 3.2 Firmas espejo (iOS ↔ Android)
`NombreUseCase(entrada) -> salida` · mismo nombre y misma firma conceptual en las dos plataformas.

### 3.3 Esquema y seguridad (diseño, no código)
- **Tablas o columnas nuevas:** …
- **Matriz rol → acción** (filas = roles del modelo de dominio; ✅ permitido · ❌ negado):

  | Rol | Leer | Crear | Editar | Borrar |
  |---|---|---|---|---|
  | … | | | | |

- **Casos de abuso** (cada uno será una prueba pgTAP que debe **negar**): …
- **Amenazas afectadas** (`docs/security/threat-model.md`): AT-xx …

### 3.4 Reglas de negocio nuevas o cambiadas
Texto exacto que se agregará a `docs/domain-model.md` (el programador lo pega **antes** de escribir código).

### 3.5 Decisiones que requieren ADR
… o "ninguna".

## 4. Preguntas abiertas · *Planificador → PO*
Si hay alguna, el flujo **se detiene** hasta que el PO responda aquí.
- [ ] P-1 …

**Aprobación del PO:** ☐ pendiente · ☐ aprobado (<fecha>) · *(solo carril completo)*

---

## 5. Implementación · *Programador*
- Commits: …
- Tests escritos (CP-xxx → archivo): …
- Desviaciones del plan y por qué: … (si cambió el plan, se anota aquí; nunca en silencio)
- Salida de `./scripts/verificar.sh`: (pegar el resumen)

## 6. Seguridad · *Agente de seguridad* (carril completo)
- Pruebas agregadas en `backend/supabase/tests/`: …
- Hallazgos: (tabla de formato abajo)

## 7. Revisión · *Revisor* (en el carril corto incluye la checklist de seguridad)
- CA cumplidos: CA-1 ✅ · CA-2 ✅ · …
- Hallazgos: (tabla de formato abajo)
- Veredicto: **Limpio** · **Con bloqueantes**

### Formato de hallazgos (seguridad y revisión)
| ID | Severidad | Archivo:línea | Qué está mal | Cómo reproducirlo | Estado |
|---|---|---|---|---|---|
| H-1 | Bloqueante / Menor | `ruta:123` | … | test, comando o pasos | Abierto / Corregido (ronda n) / Aceptado por PO |

*Bloqueante* = viola un CA, la DoD, el CLAUDE.md o el modelo de amenazas, o rompe algo existente. Lo demás es *Menor*.

## 8. Correcciones · *Corrector*
| Ronda | Hallazgo | Prueba de regresión | Commit | Suite completa |
|---|---|---|---|---|
| 1 | H-1 | `archivo › test` (falló antes, pasa después) | abc1234 | ✅ |

## 9. Entrega · *Entrega y documentación*
- PR: <enlace> · CI: ✅ / ❌ · Fusionado: <fecha> (squash)
- Migraciones aplicadas a Supabase dev: sí / no aplica
- Notion: Estado, PR, criterios y bitácora ✅ (historia y gemela)
- Plan de Pruebas: casos ejecutados registrados ✅ / pendiente
- Matriz de Trazabilidad: estado y PR ✅ / pendiente
- Docs del repo actualizados: `domain-model.md` · `threat-model.md` · ADR · spikes/README
