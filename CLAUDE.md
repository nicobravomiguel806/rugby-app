# CLAUDE.md · Reglas globales

Lee también el CLAUDE.md de la carpeta en la que trabajes (ios/, android/, backend/).

## Arquitectura (no negociable)
- Clean Architecture + MVVM. Capas: **Domain → (nada)**, **Data → Domain**, **Presentation → Domain**, **App → todas** (composición e inyección).
- Domain es código puro: no importa Supabase, SwiftUI, UIKit, Jetpack Compose, Android SDK ni Room.
- La lógica de negocio no vive en Views ni en ViewModels: va en casos de uso y reglas de Domain.
- Nombres espejo entre plataformas: `CerrarPartidoUseCase` existe en iOS y Android con la misma firma conceptual.
- `docs/domain-model.md` es la fuente de verdad de las reglas. Si cambias una regla, cambia primero el documento.

## Forma de trabajar
1. Una sesión, una historia ("Trabajemos en V-02"). Lee la historia en Notion y sus casos en el Plan de Pruebas.
2. Propón un plan por capas y los tests antes de escribir código.
3. Orden: Domain (entidades, reglas, tests) → Data (repositorio, DTO, migración) → Presentation (ViewModel, View).
4. Los tests de dominio son el contrato del port: el mismo caso debe existir en Swift y en Kotlin con el mismo ID de caso (CP-xxx).
5. Si tomas una decisión de arquitectura, regístrala en `docs/adr/`.
6. Corre tests y build antes del commit. Commit `feat(ID): …`.

## Seguridad (ver docs/security/threat-model.md)
- Cero secretos en el repo. Las llaves van en GitHub Secrets o en xcconfig/local.properties ignorados.
- La app solo usa la llave `anon`; la `service_role` nunca sale del backend ni de CI.
- Toda tabla nueva lleva RLS activa y una prueba en `backend/supabase/tests/`.
- Nunca confíes en datos del cliente para autoría o permisos: el servidor los asigna (`auth.uid()`).
- `match_events` es de solo inserción. Corregir = insertar un evento de anulación.

## Prohibido
- Importar frameworks de UI o Supabase en Domain.
- Desactivar RLS, usar `security definer` sin `set search_path`, o escribir SQL concatenando texto del usuario.
- Fusionar con el CI en rojo.
