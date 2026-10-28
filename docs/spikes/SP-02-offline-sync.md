# SP-02 · Captura offline y sincronización idempotente

**Como** anotador **quiero** registrar el partido aunque no haya señal en la cancha **para** no perder ni duplicar ninguna acción cuando vuelva la conexión.

## Pregunta
¿Cómo garantizamos cero eventos perdidos y cero duplicados (KR4 del proyecto, RNF-01)?

## Opciones evaluadas
| Opción | Problema |
|---|---|
| IDs autoincrementales del servidor | El cliente no puede crear el evento sin red; un reintento duplica |
| Sincronización "último gana" por fila | Pierde eventos concurrentes de dos anotadores |
| **UUID en el cliente + cola local ordenada + inserción idempotente en servidor** | — |

## Decisión (ADR 0002)
1. El id de cada evento es un UUID generado en el dispositivo.
2. La cola local numera los eventos (secuencia) y los envía en ese orden, en lotes.
3. El servidor inserta con `ON CONFLICT (id) DO NOTHING` y devuelve los ids confirmados; el cliente solo borra de la cola lo confirmado.
4. Si falla la red, nada se pierde: reintento con backoff 1, 2, 4… 60 s.
5. El autor y la hora del servidor los pone el servidor (`auth.uid()`, `now()`), no el cliente.

## Implementación
- Dominio: `ColaDeSincronizacion` (Kotlin y Swift) con interfaces `AlmacenLocal` y `DestinoRemoto`.
- Backend: `backend/supabase/migrations/20261028000003_sync_match_events.sql`.

## Criterios de aceptación
- **Diseño:** la cola vive en Domain y no conoce Room, SwiftData ni Supabase.
- **Interfaz gráfica:** la pantalla de partido muestra un indicador "Sin conexión · N eventos por enviar" y nunca bloquea un botón por falta de red.
- **Escenarios de prueba:** CP-130 a CP-135 (dominio) y CP-146 (servidor) en verde.

## Resultado
7 tests de dominio en Kotlin en verde + 5 pruebas de servidor (CP-146a a CP-146e) en PostgreSQL. Simulamos: sin red, red que vuelve, respuesta perdida después de guardar, varios lotes y reinicio de la app.

## Pendiente para T-05
Elegir almacén local definitivo (SwiftData vs GRDB en iOS) y medir < 300 ms por evento en un iPhone 12 (RNF-06).
