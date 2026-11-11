# ADR 0010 · Revocaciones pendientes del cierre de sesión

- **Estado:** Aceptada · 11 nov 2026 · C-02 (P-3, P-4)
- **Contexto:** cerrar sesión borra primero la sesión local y después la revoca en el servidor (P-8, SP-04). Revocar exige una credencial del usuario: `POST /auth/v1/logout` pide su JWT y la RPC `revocar_aviso_de_privacidad` usa `auth.uid()`. Hasta C-02 el access token quedaba solo en memoria entre el borrado y el logout: sin red se perdía, y con el token vencido el logout daba 401 (SP-04 H-6). CA-4 y CA-7 piden que la revocación quede pendiente en el dispositivo y se reintente.
- **Decisión:**
  - **Qué se guarda.** El **refresh token** de la sesión que se cierra, cifrado en el mismo almacenamiento seguro que la sesión y en una **entrada aparte por pendiente** que el cierre de sesión no borra. Cada entrada lleva `{usuarioId, refreshToken, versionDelAviso?, creadaEn}`.
    - iOS: Keychain, servicio `<bundle>.revocaciones`, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
    - Android: Tink AES-GCM con llave del Android Keystore (`rugbyapp_revocaciones`) sobre un DataStore aparte (`revocaciones`), con su propio *associated data* (ADR 0007).
  - **Domain no ve tokens.** `RevocacionPendiente(id, usuarioId, versionDelAvisoPorRevocar, creadaEnSegundos)` y el puerto `RepositorioDeRevocacionesPendientes` (`guardar`, `descartar`, `quitarAviso`, `pendientes`, `revocar`). `revocarSesionEnServidor()` sale de `RepositorioDeSesion`.
  - **Cómo se usa.** Solo para revocar, nunca para restaurar la sesión: `POST /auth/v1/token?grant_type=refresh_token` → si hay aviso, `rpc revocar_aviso_de_privacidad` con ese access token → `POST /auth/v1/logout?scope=local` (solo esa sesión vieja) → se borra la entrada. Los tokens del refresh nunca van al almacén de la sesión ni al cliente compartido de Supabase: se usan una vez y se olvidan. Si el refresh rota el token y el paso siguiente falla, la entrada se reescribe con el refresh token nuevo.
  - **Cuándo se da por revocada.** Cuando el servidor dice que la sesión ya no vale: 401/403/404, y 400 `refresh_token_not_found` / `refresh_token_already_used` del refresh (confirmado por el PO en la Puerta 1). Sin red, la entrada queda.
  - **Vencimiento.** A los 7 días (`7 × 86 400 s`, contados con el `Reloj` de Domain) la entrada se descarta sin usar el token.
  - **Cuándo se reintenta.** Al arrancar (antes de cualquier otra acción, con tope de 10 s que pone App), al volver la red y antes de cada inicio de sesión. Una falla no detiene las demás.
  - **La sesión nueva no se toca.** Si la misma cuenta inicia sesión, la pendiente pierde la revocación del aviso y conserva solo la de la sesión vieja (`quitarAviso(usuarioId:)`).
  - **Sin logs** de tokens: `description`/`toString()` y los clientes HTTP no los imprimen.
- **Alternativas descartadas:**
  - (a) Token en memoria (lo de SP-04): se pierde sin red.
  - (b) Guardar el access token: vence en 1 h y el logout da 401 (SP-04 H-6).
  - (c) Una Edge Function con `service_role`: más superficie y un endpoint que revoque a X sin la credencial de X.
- **Consecuencias:** (+) cerrar sesión y rechazar el aviso sin red terminan revocando en el servidor; el orden y los casos límite se prueban sin red (CP-167, CP-168). (−) Una excepción documentada a CA-3 («cerrar sesión limpia los datos locales») y, hasta que haya red o hasta 7 días, el dispositivo guarda una credencial válida de una sesión cerrada (residual de AT-10).
