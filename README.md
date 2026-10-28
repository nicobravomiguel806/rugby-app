# Rugby App · Control de torneos de rugby

App nativa para iOS (SwiftUI) y Android (Jetpack Compose) con backend en Supabase para operar torneos de rugby de punta a punta: comunidad y equipos, torneos por modalidad (7, 10, 13, 15 y festivales), registro del partido en sus tres etapas aun sin señal, reportes y tablas.

## Estructura

```
rugby-app/
├── CLAUDE.md                 Reglas globales para Claude Code
├── docs/                     Arquitectura, modelo de dominio, ADR, SPIKEs, seguridad y reportes de pruebas
├── backend/supabase/         Migraciones SQL, políticas RLS, funciones y pruebas de base de datos
├── ios/                      App SwiftUI · Swift Packages Domain / Data / Presentation
├── android/                  App Compose · módulos Gradle :domain / :data / :presentation / :app
└── .github/workflows/ci.yml  Integración continua
```

Arquitectura: **Clean Architecture + MVVM** con la misma estructura en ambas plataformas. Ver [docs/architecture.md](docs/architecture.md).

## Cómo correr las pruebas

| Qué | Comando | Requiere |
|---|---|---|
| Dominio Android (Kotlin) | `cd android && ./gradlew :domain:test` | JDK 17 |
| Dominio Android sin red | `./android/scripts/run-domain-tests.sh` | JDK 17 + Gradle instalado |
| Dominio iOS (Swift) | `cd ios/Packages/Domain && swift test` | Xcode 15.4+ |
| Base de datos (RLS y sync) | `./backend/scripts/run-db-tests.sh` | PostgreSQL 15+ |
| Base de datos con Supabase | `cd backend && supabase start && supabase db reset` | Supabase CLI + Docker |

## Flujo de trabajo

- Una rama por historia: `feat/V-02-registrar-puntuacion` (iOS) o `feat/AN-V-02-…` (Android). Los SPIKE usan `spike/SP-01-…`.
- Commits `feat(V-02): …`, `spike(SP-01): …`, `test(…)`, `docs(…)`.
- PR a `main` con el ID en el título; squash merge con el CI en verde.
- Etiqueta `vX.Y.0` al cerrar cada sprint.

## Documentación del proyecto

Product Backlog en Notion, Matriz de Trazabilidad y Plan de Pruebas en Google Sheets, diagramas en Lucidchart. Los enlaces están en el documento **Recursos — Rugby App** de la carpeta del proyecto en Drive.
