# ADR 0004 · Proyecto de Xcode con XcodeGen e identificadores de la app

- **Estado:** Aceptada · 5 nov 2026 · T-03 / AN-T-03
- **Contexto:** la app de iOS necesita un target `RugbyApp` que componga los paquetes locales Domain, Data y Presentation. Un `.xcodeproj` versionado genera conflictos de merge en el `.pbxproj` y los agentes no deben editarlo a mano. Además, las dos apps necesitan un identificador antes de tener nombre comercial definitivo.
- **Decisión:**
  - `ios/project.yml` (XcodeGen) es la fuente del proyecto y va versionado. El `.xcodeproj` se genera con `xcodegen generate` en `ios/scripts/build-app.sh` y en el job `ios-app` del CI, y se ignora en git (`ios/*.xcodeproj/`). Nadie edita el `.pbxproj` a mano.
  - El esquema `RugbyApp` compila la app y corre `RugbyAppUITests` y `PresentationTests` en el simulador. Domain y Data se prueban con `swift test` en macOS.
  - XcodeGen pasa a ser una herramienta obligatoria (`brew install xcodegen`); `build-app.sh` falla con un mensaje claro si no está.
  - Se descarta **Tuist**: trae su propio DSL en Swift y su caché, más de lo que pide un solo target de app con tres paquetes locales.
  - **Decisión provisional:** el bundle id de iOS y el `applicationId` de Android son `mx.rugbyapp`, cada uno definido en un solo lugar: `ios/RugbyApp/Config/Base.xcconfig` (`APP_BUNDLE_ID`; `project.yml` usa `$(APP_BUNDLE_ID)` y `$(APP_BUNDLE_ID).uitests`) y `android/gradle.properties` (`rugbyapp.applicationId`, leído por `android/app/build.gradle.kts`). El namespace de Kotlin (`mx.rugbyapp.app`, `.data`, `.presentation`, `.domain`) es fijo y no depende de ese id. **El id definitivo se decide antes del primer build a TestFlight / Google Play.**
- **Consecuencias:** (+) sin conflictos en el `.pbxproj`; el proyecto se reproduce igual en local y en CI; cambiar el id es editar una línea por plataforma. (−) XcodeGen es una dependencia más del entorno; abrir el proyecto en Xcode exige correr antes `xcodegen generate` (o `build-app.sh`).
