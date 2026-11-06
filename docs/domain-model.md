# Modelo de dominio · fuente de verdad de las reglas

Las reglas se describen aquí en lenguaje natural. El código de Swift y Kotlin las implementa y los tests (mismo CP-xxx en ambas plataformas) las verifican.

## 1. Perfiles y permisos
- Un perfil puede tener varios tipos: fan, jugador, entrenador, manager, médico, árbitro y padre/tutor.
- Un **menor** (menos de 18 años) solo es visible para él mismo, sus tutores aprobados, el staff aprobado de su equipo y los administradores de su comunidad.
- La tutela la solicita el tutor y la **valida un administrador**; nadie se aprueba a sí mismo.
- El tipo **médico** solo lo asigna un administrador.
- Los **datos médicos** los ven el propio jugador, sus tutores y el médico de su equipo. Un registro médico no se edita: se corrige con uno nuevo.
- Jerarquía administrativa: MasterUser (creado por soporte) → nombra Directores de Competencia → nombran Administradores de Torneo.
- **Cerrar sesión** cierra solo la sesión de este dispositivo. Primero borra siempre la sesión guardada en el dispositivo, aunque no haya red, y después intenta revocarla en el servidor; si la revocación falla, el cierre local se mantiene.

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
