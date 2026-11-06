# SP-04 · Autenticación nativa con Supabase

**Como** desarrollador **quiero** probar el inicio de sesión con Google con Supabase Auth y el guardado seguro de la sesión en iOS y Android **para** confirmar el flujo antes de C-01 y C-02.

## Pregunta
¿El ID token nativo de Google se intercambia por una sesión de Supabase sin webview, y la sesión queda cifrada en el dispositivo (Keychain en iOS, almacenamiento cifrado en Android)?

Sign in with Apple se separó a **SP-07**, porque necesita el Apple Developer Program. El PO lo contrata después del MVP y antes de publicar en App Store (guía 4.8). Su caso es CP-153.

## Decisión (ADR 0006 y ADR 0007)
Sí. La app usa `signInWithIdToken` con nonce: manda SHA-256(nonce) a Google y el nonce crudo a Supabase, con `skip_nonce_check = false`. En iOS se usa GoogleSignIn-iOS 9.0.0 y en Android Credential Manager con `googleid`. La sesión va en Keychain (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`) en iOS. En Android va en un DataStore cifrado con AES-GCM (Tink) y llave del Android Keystore, sin `security-crypto` (ADR 0007). Cerrar sesión borra primero lo local, sin usar la red, y después revoca en el servidor (regla P-8 de `docs/domain-model.md`).

## Implementación
- Domain (Swift y Kotlin): `IniciarSesionUseCase`, `ObtenerSesionActualUseCase` y `CerrarSesionUseCase`, con los puertos `ObtenedorDeCredencial`, `GeneradorDeNonce`, `HashDeNonce` y `RepositorioDeSesion`.
- Data: `RepositorioDeSesionSupabase`, `AlmacenDeSesionKeychain` (iOS) y `AlmacenDeSesionCifrado` (Android).
- App: los obtenedores de credencial de Google. En iOS, además, `RepositorioDeSesionSinRastroDeGoogle`.
- Backend: proveedor Google en `backend/supabase/config.toml` y `backend/supabase/tests/20_usuario_sin_perfil.test.sql`, con 23 casos.
- Android: respaldo desactivado (`allowBackup="false"`, `dataExtractionRules`, `fullBackupContent`) y permiso `INTERNET`.

## Criterios de aceptación
- **Diseño:** el token nunca se guarda en UserDefaults ni en SharedPreferences sin cifrar. ✅ En Android el respaldo excluye la sesión y la base local (AT-17). ✅
- **Interfaz gráfica:** botón oficial de Google según su guía de marca. ✅ (el de Apple pasa a SP-07)
- **Escenarios de prueba:** CP-158 inicio con Google, CP-154 la sesión persiste al reabrir, CP-155 cerrar sesión borra el token y CP-159 el nonce. ✅

## Resultado
**Done** (PR #7, squash `ed99830`, 2026-11-06). El CI quedó en verde (run 42289345237). En iOS corre con Xcode 16.4 (`macos-15`) y simulador de runtime iOS 17.5, con deployment target iOS 17.0 (H-18, plan B del PO). En Android corre en API 29. El PO ejecutó los manuales CP-158, CP-154 y CP-155 en un iPhone 18 Pro (iOS 27) y en un Pixel 8 (API 37), todos ✅. Lo que queda pendiente está en `docs/historias/SP-04.md` §9.
