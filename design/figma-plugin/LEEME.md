# Rugby App · Constructor de flujos (plugin de Figma)

Construye en tu archivo de Figma:

- **Atomic Design iOS** y **Atomic Design Android**: átomos (color, tipografía, iconos, espaciado), moléculas, organismos (componentes reales de Figma) y plantillas.
- **Una página por rol** (Todos los usuarios, Fan, Jugador, Padre / Tutor, Entrenador / Manager, Médico, Árbitro / Anotador, Administrador de Torneo, Director de Competencia y MasterUser). Cada historia de usuario es una columna con:
  - su ID (abre la historia en Notion) y el texto «Yo como… quiero… para…»;
  - enlaces a Notion iOS y a la gemela de Android;
  - «Depende de»: cada dependencia lleva a la columna de esa historia, aunque esté en otro rol;
  - la ruta completa, paso a paso, con la acción que lleva a la siguiente pantalla (borde ámbar = el toque).
- Flechas de dependencia entre historias del mismo rol, arriba de las columnas.

Las apps de iOS y Android son iguales, así que las páginas por rol usan los componentes de iOS; la diferencia visual de Android está en su Atomic Design.

## Cómo correrlo (una sola vez, 2 minutos)

1. Abre **Figma de escritorio** (los plugins en desarrollo no corren en el navegador).
2. Abre el archivo **Rugby App — Interfaz gráfica MVP** (o el archivo donde quieras los flujos).
3. Menú **Plugins → Development → Import plugin from manifest…** y elige `manifest.json` de esta carpeta.
4. Menú **Plugins → Development → Rugby App · Constructor de flujos**.
5. Espera a que diga «Listo». Copia los enlaces que aparecen y pégalos en el chat con Claude para ligarlos en Notion.

### Si tu archivo es del plan Starter

Starter permite 3 páginas por archivo. El plugin lo detecta y pone todo en una sola página, «Rugby App · Flujos por rol», con **una sección por rol** y por Atomic Design. Si lo corres en un equipo con más páginas, crea una página por cada uno.

### Volver a correrlo

Se puede correr las veces que quieras: reemplaza las páginas (o secciones) que creó la vez anterior. También elimina las páginas «Tokens y componentes» y «Pantallas MVP · iOS» del Sprint 2, porque esto las sustituye.

## Cambiar flujos

La fuente de verdad es `build/flows.py` en el repo (`design/figma-plugin/`): roles, historias por rol, dependencias y pantallas. Después de editarla, `./build.sh` regenera el plugin y lo prueba contra un simulador del API de Figma.
