# ADR 0003 · Permisos con RLS y funciones auxiliares SECURITY DEFINER

- **Estado:** Aceptada · 28 oct 2026 · SP-03
- **Contexto:** ocho tipos de usuario y datos sensibles (menores y salud). No queremos un backend propio que mantener.
- **Decisión:** RLS activa y cerrada por defecto en las 22 tablas. Las reglas de pertenencia (¿es tutor?, ¿es staff?, ¿es oficial?) se escriben una vez como funciones `SECURITY DEFINER` con `search_path = public, pg_temp` y se reutilizan en las políticas. `match_events` además tiene un trigger que impide update/delete.
- **Consecuencias:** (+) la seguridad no depende de la app; las pruebas corren en CI. (−) cada tabla nueva requiere su política y su prueba (incluido en la Definición de Done).
