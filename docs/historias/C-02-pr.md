# feat(C-02): inicio y cierre de sesión, recuperación de contraseña y aviso con conexión (+AN-C-02)

## Historia
- **C-02 · Inicio y cierre de sesión** · [Notion](https://app.notion.com/p/404a4935d146813f8b89ea0528f753b0) · gemela **AN-C-02** · [Notion](https://app.notion.com/p/404a4935d146815fa574f355bdb43839)
- Contrato: [`docs/historias/C-02.md`](https://github.com/nicobravomiguel806/rugby-app/blob/feat/C-02-inicio-de-sesion/docs/historias/C-02.md) · Rama: `feat/C-02-inicio-de-sesion` · Carril completo · 8 + 8 pts
- Depende de SP-04 (#7) y C-01 (#10, cierre #11). La rama está rebasada sobre `main` `8297165`.

Una persona inicia sesión con correo y contraseña o con Google, recupera su contraseña con un enlace
(PKCE, `rugbyapp://recuperar-contrasena`) y cierra sesión desde «Cuenta» con una hoja de confirmación.
Un enlace de verificación o de recuperación vencido lleva a «Enlace inválido», que pide el correo si la
app se abrió en frío. Por decisión del PO, **aceptar o rechazar el aviso de privacidad requiere conexión**
(ADR 0011).

## Regla nueva del PO: ADR 0011 (2026-11-12)
- **Aceptar o rechazar el aviso requiere conexión.** Si no se puede consultar o registrar la decisión, la app muestra «No pudimos registrar tu decisión. Revisa tu conexión» con «Reintentar». La persona se queda en el aviso, la sesión no se cierra y no se guarda nada en el dispositivo.
- **Se eliminó la revocación pendiente.** Ya no existen la cola de revocaciones ni el reintento al arrancar o al volver la red, y tampoco `MonitorDeRed`. El ADR 0010 queda marcado como reemplazado. Cerrar sesión sin red es solo local: CA-3 se cumple sin excepciones.
- **Residual aceptado (H-15, AT-10).** Tras cerrar sesión sin red, la sesión sigue válida en el servidor hasta que se configure `[auth.sessions]` (T-06).
- **Criterios afectados.** Cambian CA-4, CA-6 y CA-7 de C-02 y CA-9 de C-01 (los actualiza el PO en Notion).

## Qué cambia

### Docs y reglas
- `docs/domain-model.md`: reglas de inicio de sesión, recuperación, cierre de sesión y «No aceptar el aviso» (con la condición de conexión, CP-164d, y H-14 → A-03).
- ADR nuevo `0011-decision-del-aviso-y-cierre-de-sesion-con-conexion.md`. El ADR `0010-revocaciones-pendientes.md` queda como registro, marcado «Reemplazada». Se actualizan los ADR 0008 (enlace de recuperación) y 0009 (la parte reemplazada).
- `docs/security/threat-model.md`: AT-10 (con su residual), AT-11 y AT-19, más la nueva AT-21 (sesión de recuperación).

### Domain (iOS `ios/Packages/Domain` · Android `android/domain`, mismos nombres)
- Casos de uso nuevos: `IniciarSesionConCorreoUseCase`, `PedirRecuperacionDeContrasenaUseCase`, `ConfirmarRecuperacionDeContrasenaUseCase`, `RestablecerContrasenaUseCase` y `CerrarRecuperacionAbandonadaUseCase`.
- Modelos y puertos: `CredencialesDeCorreo`, `ErrorDeRecuperacion` y `RepositorioDeRecuperacion`.
- Cambian:
  - `CerrarSesionUseCase`: borra la sesión local primero y después intenta revocarla en el servidor; sin red no guarda nada.
  - `RechazarAvisoDePrivacidadUseCase`: si falla, la sesión no se cierra y el error se propaga.
  - `ReenviarVerificacionUseCase`: valida el formato del correo.
  - `RepositorioDeSesion` y `ErrorDeAutenticacion`.

### Data
- `RepositorioDeRecuperacionSupabase`: `recover`, canje PKCE, `updateUser` y `logout scope=others`.
- `RepositorioDeSesionSupabase` agrega `grant_type=password` (`invalid_credentials`, `email_not_confirmed` y 429).
- Las respuestas que podrían revelar si un correo existe son neutras (H-2 y H-13). Solo `over_request_rate_limit` da «Demasiados intentos».
- Android: H-20 en `AlmacenDeSesionCifrado`, donde un `IOException` al leer devuelve `null` sin borrar la sesión (CA-5, CP-170).

### Presentation
- Pantallas y ViewModels nuevos en las dos plataformas: Iniciar sesión (correo y Google), Recuperar contraseña, Nueva contraseña y Enlace inválido. Cambian Acceso (hoja «¿Cerrar sesión?») y Aviso de privacidad («Reintentar»).
- Componente nuevo `CampoDeContrasena`.

### App
- **iOS:** `NavegacionDeCuenta` enruta el enlace de recuperación, detecta la recuperación abandonada y deriva Enlace inválido del estado del canje (R-6). También cambian `ContenedorDeDependencias` y `RugbyAppApp`.
- **Android:** `MainActivity` enruta los dos enlaces y se agregan `PreparacionDelArranque`, `RepositorioDeSesionSinRastroDeGoogle`, la DI y el manifiesto (host `recuperar-contrasena`).

### Backend
- Solo `backend/supabase/config.toml`, que agrega la Redirect URL `rugbyapp://recuperar-contrasena`. **Sin migraciones.**
- Prueba pgTAP nueva, `70_seguridad_inicio_de_sesion.test.sql`, que ataca la RPC `revocar_aviso_de_privacidad`.

## Pruebas
Cada caso tiene el mismo ID y el mismo nombre en Swift y en Kotlin. La tabla completa está en el §5 del contrato.

| CP | Qué cubre |
|---|---|
| CP-012, CP-013 | Sesión persistente y cierre de sesión con hoja de confirmación (manual + `AccesoViewModel` + CP-155 actualizado) |
| CP-116 | gitleaks y pruebas de los almacenes (`CierreDeSesionSinRastroTests`: ningún ítem en el Keychain tras cerrar sesión) |
| CP-164g | Rechazo del aviso sin conexión: el error se propaga y la sesión no se cierra (ADR 0011) |
| CP-165 | Inicio de sesión con correo y con Google (Domain, Data, VM y UI) |
| CP-166 | Recuperación de contraseña (Domain, Data, VM), C02-7 y C02-8 neutros |
| CP-167a/h, CP-168a/b/c | Cierre de sesión y aviso con el significado nuevo del ADR 0011 (§8, ronda 2) |
| CP-169 | Enlace inválido o vencido: VM, UI en frío (`EnlaceInvalidoUITests`, `EnlaceInvalidoTest`) y R-6 (`EnlaceInvalidoEnFrioTests` / `…Test`) |
| CP-170 | Android: `IOException` al leer la sesión (instrumentada) |

**Verificación local final:** `./scripts/verificar.sh --todo` sobre `f7a9cd1`, con el emulador Pixel_8. Terminó con exit 0.
```
✅ architecture-guard
✅ secrets-scan (gitleaks)
✅ backend (migraciones + RLS)
✅ ios-domain (swift test)
✅ ios-app (build + tests en simulador)
✅ android-domain (:domain:test)
✅ android-app (assembleDebug + tests)   connectedDebugAndroidTest 21/21
```
- **Estabilidad de R-6:** `EnlaceInvalidoUITests` 30 iteraciones, 60/60 sin fallas. `EnlaceInvalidoEnFrioTests` 10 iteraciones, 20/20.
- **Commit de documentación de la entrega** (R-10 a R-12): solo docs y un KDoc. Después se corrieron `architecture-guard.sh` y `gitleaks git`, los dos en verde.

## Checklist de la Definición de Done
- [x] Criterios de aceptación cumplidos (CA-1 a CA-3, CA-5, CA-8, D-5 a D-9 y CA-9 a CA-11 de la gemela). CA-4, CA-6 y CA-7 se cumplen según el ADR 0011; el PO actualiza su texto en Notion.
- [x] Domain no importa frameworks (`architecture-guard` en verde)
- [x] Tests de dominio nuevos en Swift **y** Kotlin con el mismo CP-xxx (paridad revisada en §7)
- [x] Si toca datos: sin migración ni tablas nuevas. Hay prueba pgTAP de la RPC del aviso (`70_seguridad_inicio_de_sesion.test.sql`)
- [x] Sin secretos (`gitleaks` en verde)
- [ ] Casos ejecutados en el Plan de Pruebas y estado actualizado en la RTM: se hace en la fase de cierre (ver Pendientes)
- [x] Amenazas revisadas en `docs/security/threat-model.md` (AT-10, AT-11, AT-19 y AT-21)

## Hallazgos (§6 seguridad y §7 revisión)
| Estado | Hallazgos |
|---|---|
| Corregidos | H-1, H-2, H-3, H-8, R-1, R-2 y R-3 (ronda 1) · H-6 y H-13 (ronda 2) · H-15, H-16 (arreglo operativo), H-17, R-7 y R-8 (ronda extra) · R-6 (ronda extra 2, iOS) · R-10, R-11 y R-12 (entrega, solo docs) |
| Cerrados por eliminación (ADR 0011) | H-9, H-10, H-11, H-12, R-4 y R-5 |
| Resuelto en el rebase | R-9 (ADR 0009 y AT-20 de C-01) |
| Pasa a otra historia | H-14 → A-03 (Mayor, decisión del PO del 2026-11-13) |
| Pendientes (Menores, decisión del PO del 2026-11-12) | H-4, H-5 y H-7 |

No queda ningún bloqueante abierto.

## Pendientes conocidos
- **H-4:** la marca «recuperación en curso» se escribe después del canje. Si falla la escritura o la app muere entre los dos pasos, la sesión de recuperación queda sin marca.
- **H-5:** (a) un enlace de recuperación que llega con una sesión iniciada la reemplaza sin `CerrarSesionUseCase`; (b) un enlace de verificación que llega en Nueva contraseña cambia la ruta sin `abandonar()`.
- **H-7:** si `cerrarOtrasSesiones` falla, reintentar «Guardar» recibe `same_password`.
- **H-14 → A-03:** se puede entrar a la app con sesión y sin una decisión del aviso registrada. Pasa (a) en un arranque sin red, (b) con un enlace en frío que falla y (c) en la variante en caliente. La solución de raíz es exigir el aviso en RLS (A-03), invirtiendo C02-S7.
- **`[auth.sessions]` → T-06 (H-15):** decidir `timebox` / `inactivity_timeout` y confirmar en dev el agravante de SP-04: un cierre de sesión con red y el access token vencido no revoca el refresh token.
- **H-16, antes de las pruebas manuales:** revocar en Supabase dev las sesiones de las cuentas de prueba usadas con builds anteriores a `b3739f3`. En Android, además, desinstalar la app o borrar sus datos.
- **Notion (lo hace el PO):** CA-4, CA-6 y CA-7 de C-02 y CA-9 de C-01 cambian por el ADR 0011.
- **Plan de Pruebas (fase de cierre):** dar de alta CP-165 a CP-170, incluidos CP-165g/h, y el significado nuevo de CP-164g, CP-165d/e, CP-167a/h y CP-168a/b/c. Retirar CP-167b–g y CP-167i. En la Matriz, sacar `ReintentarRevocacionesPendientesUseCase` del «Componente Domain».
- **Otras historias:** «Cambiar contraseña» con sesión iniciada (historia de ajustes, P-8). CAPTCHA y límite por cuenta (T-06, residual de AT-11).
