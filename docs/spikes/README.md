# Historias SPIKE

Un SPIKE es una historia de investigación con tiempo fijo (time-box). No entrega una función al usuario: entrega **conocimiento y un prototipo** que reduce el riesgo de las historias que dependen de él. Se cierran con una decisión registrada (ADR) y pruebas que la respaldan.

| ID | Pregunta que responde | Historias que desbloquea | Time-box | Estado |
|---|---|---|---|---|
| [SP-01](SP-01-motor-de-reglas.md) | ¿Cómo modelamos las reglas de 7, 10, 13, 15 y festivales para que el mismo cálculo corra en iOS, Android y backend? | O-02, V-02, V-03, V-04, M-01 | 3 pts | **Done** |
| [SP-02](SP-02-offline-sync.md) | ¿Cómo capturamos un partido sin señal y sincronizamos sin perder ni duplicar eventos? | T-05, V-05, RNF-01, RNF-13 | 3 pts | **Done** |
| [SP-03](SP-03-rls-por-rol.md) | ¿Podemos proteger datos de menores y médicos solo con RLS de Supabase, sin backend propio? | A-03, C-05, C-06, RNF-02, RNF-04 | 3 pts | **Done** |
| [SP-04](SP-04-auth-nativa.md) | ¿Sign in with Apple y Google funcionan con Supabase Auth y la sesión queda en Keychain / EncryptedSharedPreferences? | C-01, C-02, RNF-12 | 2 pts | Sin comenzar (S1) |
| [SP-05](SP-05-realtime.md) | ¿Supabase Realtime cumple < 3 s del anotador al fan con 500 conexiones? | V-06, RNF-05 | 2 pts | Sin comenzar (S12) |
| [SP-06](SP-06-reportes-pdf.md) | ¿El reporte del partido se genera en el dispositivo o en una Edge Function? | R-02, R-03, R-04 | 2 pts | Sin comenzar (S10) |

**Avance: 3 de 6 SPIKE implementados (50%), 9 de 15 puntos.** Los pendientes se agendaron en el sprint anterior a la primera historia que desbloquean.
