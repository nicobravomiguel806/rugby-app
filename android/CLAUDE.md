# android/ · Jetpack Compose

- Módulos: `:domain` (Kotlin JVM puro), `:data` (→ :domain, supabase-kt, Room), `:presentation` (→ :domain, Compose), `:app` (composición con Hilt).
- Mismos nombres de clases y casos de uso que iOS. Antes de portar una historia, lee su versión Swift y `docs/domain-model.md`.
- ViewModel + `StateFlow`; la lógica va en casos de uso.
- Sesión en EncryptedSharedPreferences (RNF-12). `android:usesCleartextTraffic="false"`.
- Tests de Domain: `gradle :domain:test` o `./scripts/run-domain-tests.sh` sin red.
