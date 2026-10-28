# SP-03 · Seguridad por rol con Row Level Security

**Como** socio de la comunidad **quiero** que los datos de menores y los datos médicos solo los vea quien debe **para** cumplir la LFPDPPP y proteger a los jugadores.

## Pregunta
¿Alcanza RLS de Supabase para todos los permisos del proyecto (MasterUser, Director, Administrador de Torneo, staff, médico, tutor, árbitro y fan) sin un backend propio?

## Decisión (ADR 0003)
Sí. Todas las tablas con RLS activa y **cerradas por defecto**. Los permisos se expresan con funciones auxiliares `SECURITY DEFINER` con `search_path` fijo (`es_admin_comunidad`, `es_tutor_de`, `es_staff_de`, `es_medico`, `es_oficial_de`, `puede_ver_perfil`…), que evitan la recursión entre políticas y se reutilizan en todas las tablas.

## Implementación
- `backend/supabase/migrations/20261028000001_esquema_base.sql`: las 22 tablas del MER y la vista `standings`.
- `backend/supabase/migrations/20261028000002_rls_por_rol.sql`: funciones auxiliares, políticas y trigger de inmutabilidad.
- `backend/supabase/tests/10_rls_y_sync.test.sql`: 36 pruebas con 11 usuarios de prueba (uno por rol).

## Criterios de aceptación
- **Diseño:** cada tabla tiene RLS activa; ninguna política usa `using (true)` para escribir.
- **Interfaz gráfica:** cuando una consulta devuelve vacío por permisos, la app muestra "No tienes acceso a esta información" y no un error técnico.
- **Escenarios de prueba:** CP-140 a CP-150 en verde.

## Resultado
36 de 36 pruebas en verde. Bloquea: ver menores sin vínculo, leer o escribir datos médicos sin ser el médico del equipo, autoasignarse el tipo médico, nombrarse Director o MasterUser, aprobar la propia tutela, registrar eventos sin ser oficial o fuera del partido en vivo, modificar o borrar eventos, y cualquier lectura sin sesión.
