# feat(C-01): registro con correo o Google y aviso de privacidad en servidor (+AN-C-01)

> **Modo local (2026-11-11).** GitHub está suspendido. Este es el cuerpo del PR, listo para pegar con
> `gh pr create --base main` cuando el PO avise que GitHub volvió. El PR se abre entonces con el CI real
> (la Puerta 2, el merge, se decide ahí). **C-02 va apilada encima** de `feat/C-01-registro-de-usuario`.
> Después del squash merge de C-01, la rama de C-02 se rebasa sobre `main` antes de abrir su PR.

## Historia
- **C-01 · Registro de usuario** · [Notion](https://app.notion.com/p/404a4935d14681c58700ef4e91682534) · gemela **AN-C-01** · [Notion](https://app.notion.com/p/404a4935d14681d9b683f9b206725a2b)
- Contrato: [`docs/historias/C-01.md`](./C-01.md) · Rama: `feat/C-01-registro-de-usuario` · Carril completo · 5 + 5 pts
- Requisitos: RF-01, RNF-10 · Épica EP-01 · v1.0 MVP

Una persona se registra con su correo (enlace de verificación con PKCE) o con Google, y acepta el aviso de
privacidad. La aceptación queda en el servidor con versión, fecha y método de alta puestos por el servidor.
Las tres finalidades secundarias son casillas separadas y desmarcadas por defecto. Si no acepta el aviso,
se cierra la sesión y no se guarda nada (CA-9). Apple queda para SP-07.

## Qué cambia

### Docs y reglas
- `docs/domain-model.md`: sección 0 (alcance nacional) y reglas de registro y aviso, incluida la revocación como fila nueva (H-6). Se cambió antes que el código.
- ADR nuevos: `0008-enlace-de-verificacion-de-correo.md` y `0009-consentimiento-de-privacidad-en-servidor.md`. ADR 0006 con un párrafo sobre el cliente compartido.
- `docs/security/threat-model.md`: AT-11 (con el riesgo residual de H-3), AT-18 y AT-19 nueva.

### Domain (iOS `ios/Packages/Domain` · Android `android/domain`, mismos nombres)
- Modelos: `DatosDeRegistro` (no imprime la contraseña), `ErrorDeRegistro` (sin `correoYaRegistrado`), `ResultadoDeRegistro` (un solo caso: mensaje neutro), `AvisoDePrivacidad` (`v0-borrador`), `FinalidadSecundaria` y `ErrorDeConsentimiento`. `Sesion.nombre` solo se usa para mostrar.
- `ValidadorDeRegistro`: nombre de 2 a 120, correo normalizado, contraseña de 10 o más sin reglas de composición. Devuelve todos los errores en orden fijo.
- Puertos: `RepositorioDeRegistro` y `RepositorioDeConsentimiento` (aceptar, consultar, revocar).
- Casos de uso:
  - Registro y correo: `RegistrarUsuarioUseCase`, `ReenviarVerificacionUseCase` y `ConfirmarCorreoUseCase`.
  - Aviso: `AceptarAvisoDePrivacidadUseCase`, `ConsultarAvisoAceptadoUseCase`, `RechazarAvisoDePrivacidadUseCase` (revoca si había consentimiento y siempre cierra la sesión) y `HayQuePedirElAvisoAlArrancarUseCase` (carrera de H-6).

### Data
- **iOS:** producto `PostgREST` del mismo supabase-swift 2.49.0 (`Package.resolved` sin cambios). `ClienteSupabase` crea un `PostgrestClient` con el token del mismo `AuthClient`. Repositorios nuevos: `RepositorioDeRegistroSupabase` y `RepositorioDeConsentimientoSupabase`. `RepositorioDeSesionSupabase` llena `Sesion.nombre`.
- **Android:** `postgrest-kt` 3.0.2 (`version.ref = "supabase"`). Se instala `Postgrest` en el mismo `createSupabaseClient`, con el almacén cifrado de SP-04. Tiene los mismos repositorios que iOS.
- Las RPC solo reciben `p_version` (y `p_finalidades`), nunca `user_id`, `accepted_at` ni `signup_method`. No hay logs de contraseñas, enlaces ni tokens.

### Presentation
- Pantallas en iOS y Android:
  - Bienvenida y Registro (sin botón de Apple; contraseña con opción de mostrarla; tres casillas opcionales).
  - Verifica tu correo (texto neutro).
  - Aviso de privacidad (sin «atrás»; botones «Aceptar y continuar» y «No acepto»).
  - Sesión iniciada y Próximamente.
- ViewModels: `RegistroViewModel` y `AvisoDePrivacidadViewModel`. En Android, además, `EventosDeCuenta`, que atiende cada evento una sola vez al rotar (H-5).

### App
- **iOS:** contenedor con un solo cliente. `onOpenURL` envía `rugbyapp://auth-callback` a `ConfirmarCorreoUseCase` y lo demás a GoogleSignIn. Agrega `NavegacionDeCuenta`, el esquema `rugbyapp` en `project.yml` y `AVISO_DE_PRIVACIDAD_URL` vacía por defecto.
- **Android:** rutas de la cuenta en `MainActivity`, `intent-filter` `rugbyapp://auth-callback` con `singleTop` y `onNewIntent`, `buildConfigField AVISO_DE_PRIVACIDAD_URL` y módulos de Hilt.

### Backend
- Migración nueva **`backend/supabase/migrations/20261107000005_privacidad_y_comunidad.sql`**:
  - Tipos `tipo_consentimiento`, `metodo_de_alta` y `finalidad_secundaria`.
  - Tabla **`privacy_consents`** con RLS: solo `select` e `insert` propios, sin `update` ni `delete`. Un trigger sella `accepted_at` y `signup_method` desde el JWT y exige la versión vigente. Otro trigger la hace inmutable.
  - Un candado por usuario y versión, y la regla `aviso_sin_cambio`.
  - RPC `aceptar_aviso_de_privacidad`, `revocar_aviso_de_privacidad` y `aviso_de_privacidad_aceptado`, todas `security invoker` con `search_path`.
  - Trigger `perfiles_comunidad_inmutable` (AT-18 a).
- `config.toml`: `additional_redirect_urls = ["rugbyapp://auth-callback"]`. Sin secretos.
- Pruebas:
  - `00_auth_stub.sql` agrega `auth.jwt()`.
  - Archivos nuevos `30_registro`, `40_seguridad_registro`, `50_revocacion_aviso` y `60_seguridad_revocacion`, incluidos desde `10_`.
  - CP-150 pasa de 22 a **23** tablas.

## Migraciones
| Archivo | Supabase dev | Producción |
|---|---|---|
| `20261107000005_privacidad_y_comunidad.sql` | **Sin aplicar.** Se aplica en la fase de cierre, después del merge | No aplica (no existe todavía, T-02) |

La Redirect URL `rugbyapp://auth-callback` ya está configurada en Supabase dev (el PO la agregó el 6 nov 2026).

## Pruebas y casos cubiertos
`./scripts/verificar.sh --todo` en verde el 2026-11-11 (sustituye al CI mientras GitHub está suspendido):

| Job | Resultado |
|---|---|
| architecture-guard | ✅ (los casos de uso nuevos existen en Swift y en Kotlin) |
| secrets-scan (gitleaks) | ✅ |
| backend (migraciones + RLS) | ✅ 205 ok / 0 fallidas |
| ios-domain | ✅ 54 tests |
| ios-app | ✅ Data 28 · Presentation 27 · RugbyAppTests 4 · UITests 3 |
| android-domain | ✅ (54 tests, mismos ID que iOS) |
| android-app | ✅ assembleDebug + unitarias (data 29, presentation 31). Las 12 instrumentadas **no corrieron** en esta pasada porque no había emulador; pasaron en las revisiones del 2026-11-07 (Pixel_8) y corren en el CI (API 29) |

| CP | Qué cubre | Dónde | Estado |
|---|---|---|---|
| CP-160a–j | Validación del registro | Domain Swift + Kotlin | ✅ automático |
| CP-114a–f | Aviso, versión vigente y tres finalidades | Domain Swift + Kotlin, VM, Data, `RegistroUITests` | ✅ automático · parte manual pendiente (PO) |
| CP-164a–g | Rechazo del aviso, arranque sin decidir, carrera del enlace (e), revocación (f, g) | Domain Swift + Kotlin, VM, Data | ✅ automático · parte manual pendiente (PO) |
| CP-161 | AT-18 (a): `community_id` inmutable para el usuario | pgTAP `30_` y `40_` | ✅ |
| CP-162 | `privacy_consents`: el servidor pone autoría, fecha y método; solo inserción | pgTAP `30_`, `40_`, `50_` y `60_` | ✅ |
| CP-150 | 23 tablas con RLS | pgTAP `10_` | ✅ |
| CP-011 | Correo duplicado: mismo mensaje neutro | Data (`identities: []`) + manual | ✅ Data · manual pendiente (PO) |
| CP-010 | Registro con correo válido de punta a punta | Manual en iPhone y Pixel con Supabase dev | ⏳ PO |

Pruebas manuales que hace el PO tras aplicar la migración en dev:
- CP-010.
- CP-011.
- CP-114: con correo y con Google; revisar `privacy_consents`.
- CP-164, con estos **pasos obligatorios** (H-15):
  - el paso 4, cerrar la app sin decidir;
  - rotar en Aviso con casillas marcadas;
  - abrir el enlace con la app cerrada.

## Checklist de la Definición de Done
- [x] Criterios de aceptación cumplidos: CA-1, CA-2, CA-3, CA-4 y CA-9, más CA-5, CA-6 y CA-7 de la gemela (revisión ronda 2, §7). CA-8 se registra en el Plan de Pruebas al cerrar.
- [x] Domain no importa frameworks (architecture-guard ✅)
- [x] Tests de dominio nuevos en Swift **y** Kotlin con el mismo CP-xxx (54 / 54)
- [x] Toca datos: migración + RLS + pruebas en `backend/supabase/tests/` (205 ok)
- [x] Sin secretos (secrets-scan ✅)
- [ ] Casos ejecutados en el Plan de Pruebas y estado en la RTM: **pendiente**. En modo local no se registran como ejecutados en CI. Se hace en el cierre, con CP-164a–g completos (H-17)
- [x] Amenazas revisadas en `docs/security/threat-model.md` (AT-11, AT-18 y AT-19). AT-20 se agrega en el cierre (H-12)

## Hallazgos de seguridad y revisión
| ID | Sev. | Tema | Estado |
|---|---|---|---|
| H-5 | Bloqueante | Android: al rotar se repetían los eventos de navegación | **Corregido** (`a1069df`) |
| H-6 | Bloqueante | Carrera entre el enlace del correo y la consulta del aviso al arrancar, y la revocación al pulsar «No acepto» | **Corregido** (`6296b4b`, `d7b01c4`, `a1069df`) |
| H-3 | Menor | Riesgo residual de enumeración en AT-11 | **Corregido** en la documentación (`d6b7986`). Falta CAPTCHA y rate limit por IP → T-06 |
| H-15 | Menor | La conexión de H-5 y H-6 en App no tiene test automático | **Aceptado por el PO**: pasos obligatorios en la prueba manual de CP-164 |

Sin bloqueantes abiertos. Veredicto del revisor (ronda 2): **Limpio**. Seguridad, rondas 1 y 2: sin bloqueantes.

## Pendientes conocidos (menores abiertos)
- **H-1:** el enlace de verificación no valida el path (`rugbyapp://auth-callback/x?code=…`). No se puede explotar.
- **H-2:** `comunidad_inmutable` usa una lista de roles negados. Lo resuelve **C-03**.
- **H-4:** Android no exige `https` en `AVISO_DE_PRIVACIDAD_URL`. Hoy está vacía.
- **H-7:** falta un guardia de «inicio con Google en curso» (comparte causa con SP-04 H-11).
- **H-8:** la regla de «registrar el aviso al volver del enlace» vive en los ViewModels y no compara el correo.
- **H-9:** «espacio» no es lo mismo en Swift y en Kotlin (U+0085, U+001C a U+001F).
- **H-10:** CP-164d de Domain casi no prueba nada; volver a pedir el aviso al arrancar depende de App. Lo cubre la prueba manual.
- **H-11:** el estado vigente se calcula contando y solo es correcto con READ COMMITTED. Lo resuelve **A-03**.
- **H-12:** las finalidades siguen vigentes después de revocar el aviso. Lo resuelve **F-02**, más la fila AT-20 en el cierre.
- **H-13:** un enlace inválido suprime el aviso en ese arranque. Lo resuelve **A-03**.
- **H-14:** ADR 0009 desalineado; se corrige en el cierre. La etiqueta «check:» de C01-2h va a **T-06**.
- **H-16:** el rechazo con falla de `avisoAceptado` no tiene test. Lo resuelve **C-02**.
- **H-17:** el Plan de Pruebas debe quedar con CP-164a–g. Se hace en el cierre.
- **Van a C-02:**
  - persistir y reintentar una revocación que falló;
  - pantalla de «enlace inválido o expirado».
- **Configuración:** `AVISO_DE_PRIVACIDAD_URL` cuando exista la URL pública del aviso.
- **Android:** sin `gradle.lockfile` ni `verification-metadata.xml` (AT-16, pendiente desde SP-04 H-5).

## Nota de entrega
- El PR **todavía no está abierto**: GitHub está suspendido (modo local, `docs/flujo-de-agentes.md` § «Modo local»). Se abrirá cuando vuelva GitHub, con el CI real, y el merge requiere la aprobación del PO (Puerta 2).
- **C-02 va apilada encima de esta rama.** Se fusiona primero C-01 (squash) y después se rebasa C-02 sobre `main`.
- En Notion, C-01 y AN-C-01 están en «En revisión» con la nota «pendiente GitHub». Hasta el merge no se marca Done ni se registra el Plan de Pruebas.
