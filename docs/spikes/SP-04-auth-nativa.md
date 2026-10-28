# SP-04 · Autenticación nativa con Supabase (pendiente, S1)

**Como** desarrollador **quiero** probar Sign in with Apple y Google con Supabase Auth **para** confirmar el flujo antes de C-01 y C-02.

- **Pregunta:** ¿el token nativo de Apple/Google se intercambia por una sesión de Supabase sin webview y la sesión se guarda en Keychain (iOS) y EncryptedSharedPreferences (Android)?
- **Requiere:** cuenta de Apple Developer, proyecto Supabase dev (T-02) y cliente OAuth de Google.
- **Criterios de aceptación:**
  - Diseño: el token nunca se guarda en UserDefaults ni en SharedPreferences sin cifrar.
  - Interfaz gráfica: botones oficiales de Apple y Google según sus guías de marca.
  - Escenarios de prueba: CP-153 inicio con Apple, CP-154 sesión persiste al reabrir, CP-155 cerrar sesión borra el token.
- **Time-box:** 2 pts.
