# SP-05 · Marcador en vivo con Supabase Realtime (pendiente, S12)

**Como** fan **quiero** ver el marcador actualizado en segundos **para** seguir el partido sin estar en la cancha.

- **Pregunta:** ¿Realtime (Postgres Changes o Broadcast) entrega un evento en menos de 3 s (RNF-05) con 500 suscriptores, respetando RLS?
- **Plan:** prototipo con un canal por partido; prueba de carga con k6 desde 500 clientes simulados; medir p95 de latencia anotador → fan.
- **Criterios de aceptación:**
  - Diseño: el fan se suscribe solo al canal del partido; no recibe eventos de partidos privados.
  - Interfaz gráfica: el marcador anima el cambio y muestra "En vivo" o "Reconectando…".
  - Escenarios de prueba: CP-067 (p95 < 3 s) y CP-156 (desconexión y reconexión sin perder el marcador).
- **Time-box:** 2 pts.
