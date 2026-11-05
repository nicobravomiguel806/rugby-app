# Arquitectura

## Patrón: Clean Architecture + MVVM (paridad iOS / Android)

```
            ┌──────────────────────── App (composición, DI) ────────────────────────┐
            │                                                                       │
   ┌────────▼────────┐        usa         ┌───────────────┐       implementa  ┌──────▼──────┐
   │  Presentation   │ ─────────────────▶ │    Domain     │ ◀──────────────── │    Data     │
   │ View + ViewModel│                    │ Entidades     │                   │ Repositorios│
   │ SwiftUI/Compose │                    │ Casos de uso  │                   │ Remote (API)│
   └─────────────────┘                    │ Reglas        │                   │ Local (DB)  │
                                          │ Protocolos    │                   │ Mappers/DTO │
                                          └───────────────┘                   └──────┬──────┘
                                                                                     │ HTTPS / RPC / Realtime
                                                                              ┌──────▼──────┐
                                                                              │  Supabase   │
                                                                              │ Postgres+RLS│
                                                                              └─────────────┘
```

Regla de dependencias: las flechas solo apuntan hacia **Domain**. Domain no conoce a nadie.

| Capa | iOS | Android | Contiene | No puede importar |
|---|---|---|---|---|
| Domain | Swift Package `Domain` | módulo JVM `:domain` | Entidades, casos de uso, reglas por modalidad (SP-01), cola de sincronización (SP-02), protocolos de repositorio | SwiftUI, UIKit, Supabase, SwiftData / Android SDK, Compose, Room, supabase-kt |
| Data | Swift Package `Data` | módulo `:data` | Implementación de repositorios, DTO ↔ entidad, cliente Supabase, almacén local (SwiftData/GRDB · Room) | Presentation |
| Presentation | Swift Package `Presentation` | módulo `:presentation` | Views y ViewModels por feature (`@Observable` · `StateFlow`) | Data |
| App | target `RugbyApp` | módulo `:app` | Composición e inyección de dependencias, navegación, configuración | — |
| Backend | `backend/supabase` | (compartido) | Migraciones, RLS, funciones SQL y Edge Functions | — |

La regla se valida al compilar (cada capa es un módulo) y en CI (job `architecture-guard`, CP-001 / CP-100). La guardia también revisa que Presentation no importe Data y que cada `*UseCase` de Domain exista con el mismo nombre en Swift y en Kotlin.

## Inyección de dependencias (ADR 0005)

- **iOS:** `RugbyApp/App/ContenedorDeDependencias.swift` es la raíz de composición manual: crea el repositorio de Data, el caso de uso de Domain y el ViewModel de Presentation, por constructor.
- **Android:** Hilt, solo en `:app` (`di/ModuloDeDatos`, `di/ModuloDeCasosDeUso`). `MainActivity` recibe los casos de uso por `@Inject` y crea los ViewModels con una fábrica en cada ruta del `NavHost`; `:presentation`, `:data` y `:domain` no dependen de Hilt.
- El proyecto de Xcode se genera con XcodeGen desde `ios/project.yml` (ADR 0004).

## Paquetes por feature

Dentro de cada capa hay una carpeta por feature, con los mismos nombres en ambas plataformas:
`Inicio`, `Cuentas`, `Equipos`, `Administracion`, `Torneos`, `PrePartido`, `PartidoEnVivo`, `Reportes`, `Marcadores`, `Interaccion`, más `Rules` y `Sync` en Domain.

`Inicio` (T-03) es la pantalla provisional de arranque: solo existe en Presentation y App, y muestra las modalidades que devuelve `ObtenerModalidadesUseCase`. La definitiva llega con C-08.

## Flujo de un evento de partido (offline-first)

1. La View del partido en vivo llama `vm.registrar(.ensayo)`.
2. El ViewModel ejecuta `RegistrarEventoUseCase`, que valida con `MotorDePartido` (reglas de la modalidad) y genera el UUID.
3. El caso de uso guarda el evento en el almacén local y lo encola en `ColaDeSincronizacion` (< 300 ms, RNF-06).
4. Cuando hay red, la cola envía lotes a `sync_match_events` (RPC). El servidor asigna autor y hora (RNF-13) y RLS valida que sea un oficial del partido en vivo.
5. El marcador de los fans se actualiza por Supabase Realtime (SP-05).

Diagramas: paquetes y despliegue en Lucidchart (ver documento del Sprint 2).
