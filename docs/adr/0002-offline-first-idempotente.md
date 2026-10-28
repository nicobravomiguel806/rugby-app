# ADR 0002 · Offline-first con UUID de cliente e inserción idempotente

- **Estado:** Aceptada · 28 oct 2026 · SP-02
- **Contexto:** las canchas no tienen señal confiable; KR4 exige cero eventos perdidos en modo avión.
- **Decisión:** UUID generado en el dispositivo, cola local ordenada por secuencia, envío por lotes a `sync_match_events` con `ON CONFLICT (id) DO NOTHING`, confirmación por id y backoff exponencial con tope de 60 s. El servidor asigna autor y hora.
- **Consecuencias:** (+) reintentar siempre es seguro; dos anotadores pueden capturar a la vez. (−) los conflictos de contenido (dos personas anotan el mismo ensayo) no se resuelven solos: se muestran al Administrador al cerrar el partido (R-01).
