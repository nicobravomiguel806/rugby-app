# Modelo de dominio · fuente de verdad de las reglas

Las reglas se describen aquí en lenguaje natural. El código de Swift y Kotlin las implementa y los tests (mismo CP-xxx en ambas plataformas) las verifican.

## 0. Alcance nacional: Asociación, ligas y equipos
- La app es **nacional y multi-liga**: cubre todas las ligas, equipos y partidos de la Asociación Mexicana de Rugby, de cualquier modalidad y rama.
- Jerarquía: **Asociación → ligas (comunidades) → equipos**. En los datos, una liga es una comunidad (`communities`).
- Los **datos deportivos** (equipos, torneos, partidos, resultados, tablas y estadísticas) son visibles para cualquier usuario autenticado, sea de la liga que sea.
- Los **datos personales** siguen restringidos por rol (sección 1).
- Un **aficionado** no necesita pertenecer a una liga.
- Un **jugador o staff** entra a una liga por una **solicitud que aprueba el Director de esa liga**. Nadie elige ni cambia por su cuenta la liga de su perfil (AT-18).

## 1. Perfiles y permisos
- Un perfil puede tener varios tipos: fan, jugador, entrenador, manager, médico, árbitro y padre/tutor.
- Un **menor** (menos de 18 años) solo es visible para él mismo, sus tutores aprobados, el staff aprobado de su equipo y los administradores de su comunidad.
- La tutela la solicita el tutor y la **valida un administrador**; nadie se aprueba a sí mismo.
- El tipo **médico** solo lo asigna un administrador.
- Los **datos médicos** los ven el propio jugador, sus tutores y el médico de su equipo. Un registro médico no se edita: se corrige con uno nuevo.
- Jerarquía administrativa: MasterUser (creado por soporte) → nombra Directores de Competencia → nombran Administradores de Torneo.
- **Cerrar sesión** cierra solo la sesión de este dispositivo. Primero borra siempre la sesión guardada en el dispositivo, aunque no haya red, y después intenta revocarla en el servidor. Si la revocación falla, el cierre local se mantiene y la revocación queda **pendiente** en el dispositivo: se guarda el refresh token cifrado en el mismo almacenamiento seguro, se usa solo para revocar (nunca para restaurar la sesión) y se borra al revocar con éxito o a los 7 días. Es la única excepción a «cerrar sesión limpia los datos locales». La revocación pendiente se reintenta al recuperar la red o en el siguiente arranque, antes de cualquier otra acción. Sin red, la app no se bloquea: lo intenta hasta 10 segundos y luego sigue. La revocación pendiente solo aplica a la sesión vieja de ese dispositivo: si la misma cuenta inicia sesión o acepta el aviso después, no toca la sesión nueva ni la aceptación nueva. Si el servidor responde que la sesión ya no vale, se da por revocada y se borra la pendiente.
- **Registro (C-01).** Una persona crea su cuenta con correo y contraseña o con Google (Apple se agrega en SP-07). Con correo, la cuenta queda pendiente hasta que abre el enlace de verificación que recibe; sin verificar no inicia sesión. Con Google, el primer inicio de sesión crea la cuenta. Registrarse no asigna liga ni crea el perfil (C-03).
- **Datos del registro con correo.** Nombre completo de 2 a 120 caracteres, contados después de quitar los espacios del inicio y del final. Correo con formato válido, que se guarda sin espacios al inicio y al final y en minúsculas. Contraseña de 10 caracteres o más, sin reglas de composición. No se pide confirmar la contraseña; el formulario permite mostrarla.
- **El nombre del registro** se guarda en los datos de la cuenta solo para mostrarlo (saludo y precarga del perfil en C-03). Nunca decide permisos.
- **Correo ya registrado (AT-11).** Registrarse con un correo que ya tiene cuenta muestra el mismo mensaje neutro que un registro nuevo y no crea otra cuenta. La app nunca confirma si un correo existe.
- **Aviso de privacidad (RNF-10, LFPDPPP).** Nadie completa el registro sin aceptar la versión vigente del Aviso de Privacidad: con correo, en el formulario; con Google, en su primer inicio de sesión. La aceptación se guarda en el servidor con el usuario, la versión, el tipo (aviso o finalidad secundaria), la fecha y hora del servidor y el método de alta (correo o Google). Nadie la edita ni la borra; un cambio de versión pide aceptar de nuevo y crea un registro nuevo. Versión vigente: `v0-borrador`.
- **No aceptar el aviso.** Si en su primer inicio con Google la persona no acepta el aviso, se cierra la sesión en el dispositivo y no se guarda nada más: ni consentimiento ni perfil. Lo mismo aplica si lo rechaza después de verificar su correo. Si sale de la app sin aceptar ni rechazar, no se guarda nada y el aviso se vuelve a pedir en su siguiente inicio. **Excepción:** si la persona ya tenía guardada en el servidor la aceptación de la versión vigente (por ejemplo, porque se registró justo al volver del enlace del correo) y pulsa «No acepto», se registra la revocación como un registro nuevo del aviso con la decisión «no acepta» antes de cerrar la sesión, porque los consentimientos no se editan ni se borran. El aviso vigente de cada persona es su registro más reciente: tras la revocación vuelve a pedirse y se puede aceptar otra vez. Si no había aceptación guardada, sigue sin guardarse nada. Si no se puede consultar o registrar la revocación (por ejemplo, sin red), la sesión del dispositivo se cierra de todas formas y la revocación del aviso queda pendiente junto con la de la sesión: al reintentar, primero se registra la revocación del aviso y después se revoca la sesión. Si el aviso no estaba aceptado, no se guarda nada.
- **Finalidades secundarias** (notificaciones de lo que sigues, comunicaciones de las ligas o de la Asociación, estadísticas anónimas). Son opcionales y cada una tiene su propia casilla, desmarcada por defecto; el aviso indica que puedes negarte a cada una. Negarse a una o a todas no impide usar la app. Se guarda la decisión de cada una, también la negativa.
- **Inicio de sesión (C-02).** Con correo y contraseña o con Google. El correo se usa sin espacios al inicio y al final y en minúsculas; la contraseña, tal como se escribió. Un correo o una contraseña incorrectos muestran el mismo mensaje: «Correo o contraseña incorrectos.» Con demasiados intentos: «Demasiados intentos. Espera unos minutos e inténtalo de nuevo.» Una cuenta sin verificar no inicia sesión: «Confirma tu correo para entrar. Te enviamos un enlace.», con el botón «Reenviar correo». El límite es de 30 intentos por IP cada 5 minutos.
- **Recuperar la contraseña.** Se pide con el correo y siempre se muestra el mismo mensaje, exista o no la cuenta: «Si hay una cuenta con ese correo, te enviamos un enlace para restablecer tu contraseña.» También cuando el servidor ya no deja enviar más correos a esa dirección: ese límite solo existe si la cuenta existe. «Demasiados intentos» solo aparece con el límite por IP, que es igual para cualquier correo (C-02 H-2). El enlace abre la app y pide la nueva contraseña, que sigue la regla del registro: 10 caracteres o más, sin reglas de composición. Después del cambio, la sesión queda iniciada en ese dispositivo y se cierran las sesiones en los demás. Si la persona abandona el cambio (incluso si cierra la app), se cierra la sesión de recuperación y vuelve a Iniciar sesión.
- **Enlace inválido o expirado.** Si el enlace del correo ya no sirve, la app muestra «Este enlace ya no es válido o expiró», sin detalles técnicos. Si era de verificación, ofrece «Reenviar correo»; si la app no conoce el correo (se abrió desde el enlace), lo pide antes de reenviar. Después de reenviar muestra «Si el correo está registrado y sin confirmar, te enviamos un nuevo enlace. Revisa también tu carpeta de spam.», exista o no la cuenta, con la misma regla de límites que la recuperación. Si era de recuperación, ofrece «Pedir otro enlace», que lleva a Recuperar contraseña.

## 2. Reglas por modalidad (SP-01)

| | XV (15) | 10s | 7s | Rugby 13 | Festival |
|---|---|---|---|---|---|
| Jugadores en cancha | 15 | 10 | 7 | 13 | 7* |
| Tiempos × minutos | 2 × 40 | 2 × 10 | 2 × 7 | 2 × 40 | 2 × 10* |
| Ensayo | 5 | 5 | 5 | 4 | — |
| Conversión | 2 | 2 | 2 | 2 | — |
| Penal | 3 | 3 | 3 | 2 | — |
| Drop | 3 | 3 | 3 | 1 | — |
| Ensayo de penal | 7 | 7 | 7 | no existe | — |
| Expulsión temporal (amarilla) | 10 min | 2 min* | 2 min | 10 min | — |
| Cambios permitidos | 8 | 5* | 5 | 8* | libres |
| Lleva marcador / cuenta en tabla | sí | sí | sí | sí | **no** |

\* Valores por defecto **por validar con el socio**. Todos se pueden sobrescribir por torneo en `tournament_rules`.

Reglas de secuencia:
- Una **conversión** solo es válida si el último evento del partido fue un ensayo del mismo equipo.
- Con **tarjeta roja** el equipo juega con uno menos el resto del partido; el jugador no vuelve.
- Con **amarilla** el jugador vuelve al cumplirse los minutos de la modalidad.
- Un jugador expulsado (temporal o definitivo) no puede anotar ni ser parte de un evento.
- Los festivales no aceptan anotaciones: solo registran participación.

## 3. Eventos del partido (RNF-13)
- El estado del partido (marcador, jugadores en cancha) **se deriva** de la lista de eventos; nunca se guarda a mano.
- Los eventos son de **solo inserción**. Corregir = registrar un evento `anulacion` que apunta al evento anulado.
- Cada evento guarda: id generado en el dispositivo, autor (lo asigna el servidor), minuto, hora del dispositivo, secuencia del dispositivo y hora del servidor.

## 4. Sincronización offline (SP-02)
- El evento se guarda primero en el dispositivo; la red nunca bloquea la captura.
- Se envía en el orden de captura, en lotes de hasta 50 (el servidor acepta hasta 200).
- Reenviar es seguro: el servidor ignora ids que ya tiene.
- Si falla, se reintenta con espera exponencial 1, 2, 4… hasta 60 s.
