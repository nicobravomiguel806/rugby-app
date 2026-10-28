# -*- coding: utf-8 -*-
"""Fuente de verdad del Figma: roles, historias por rol, dependencias y flujo de pantallas.
Cada pantalla es una lista de elementos que el plugin dibuja con los componentes del Atomic Design.
Un 1 al final de un elemento marca el toque que lleva a la siguiente pantalla (se resalta en ámbar)."""
import json, os

ROLES = [
 ("Todos los usuarios", "Lo que cualquier persona hace en la app, tenga el rol que tenga.", ["C-01","C-02","C-03","C-07","F-03"]),
 ("Fan", "Sigue equipos, torneos y marcadores sin estar en la cancha.", ["F-01","V-06","F-02","M-01","M-03","M-04"]),
 ("Jugador", "Completa sus datos deportivos, se une a un equipo y consulta su rendimiento.", ["C-04","E-02","E-04","M-03"]),
 ("Padre / Tutor", "Autoriza y acompaña a su hijo menor de edad.", ["C-05"]),
 ("Entrenador / Manager", "Forma y administra su equipo, registra plantillas y alineaciones.", ["E-01","E-03","E-04","O-04","P-02","R-02"]),
 ("Médico", "Registra aptitud y lesiones de los jugadores de su equipo. Datos de acceso restringido.", ["C-06","R-03"]),
 ("Árbitro / Anotador", "Opera el partido en la cancha: check-in, reloj, anotaciones, tarjetas y cierre.", ["P-03","V-01","V-02","V-03","V-04","V-05","R-01","R-04"]),
 ("Administrador de Torneo", "Opera el día a día del torneo: inscripciones, calendario, oficiales y reportes.", ["O-03","O-05","P-01","R-02"]),
 ("Director de Competencia", "Crea y configura torneos de su comunidad y nombra administradores.", ["O-01","O-02","O-06","A-02","M-02"]),
 ("MasterUser", "Dueño de la comunidad: nombra a los Directores de Competencia.", ["A-01"]),
]

ACT = {"C":"Unirme a la comunidad","E":"Formar equipo","A":"Administrar la competencia","O":"Organizar el torneo",
       "P":"Preparar el partido","V":"Jugar el partido","R":"Cerrar y reportar","M":"Consultar resultados","F":"Seguir y enterarme"}

DEPS = {
 "C-01":[], "C-02":["C-01"], "C-03":["C-01"], "C-04":["C-03"], "C-05":["C-03"], "C-06":["C-03","E-03"], "C-07":["C-03"],
 "E-01":["C-03"], "E-02":["C-03","E-01"], "E-03":["E-02"], "E-04":["E-03"],
 "A-01":["C-03"], "A-02":["A-01","O-01"],
 "O-01":["A-01"], "O-02":["O-01"], "O-03":["O-01","A-02","E-01"], "O-04":["O-03","E-03","C-04"], "O-05":["O-03"], "O-06":["O-01"],
 "P-01":["O-05","A-02"], "P-02":["O-04","O-05"], "P-03":["P-01","P-02"],
 "V-01":["P-03"], "V-02":["V-01"], "V-03":["V-01"], "V-04":["V-02"], "V-05":["V-02"], "V-06":["V-02"],
 "R-01":["V-02","V-03","V-04"], "R-02":["R-01"], "R-03":["R-01","C-06"], "R-04":["R-01","V-03"],
 "M-01":["R-01"], "M-02":["M-01","O-02"], "M-03":["R-01"], "M-04":["M-03"],
 "F-01":["C-03"], "F-02":["F-01","V-02"], "F-03":["R-01"],
}

def S(n, els, go=None, tab="Inicio", back=None, dark=False):
    return {"n":n, "els":els, "go":go, "tab":tab, "back":back, "dark":dark}

def home(nombre, sub, acciones, hl, extra=None, tab="Inicio"):
    els = [["h1", f"¡Hola, {nombre}!"], ["p", sub], ["actions", acciones, hl]]
    els += extra or [["section","Próximo partido"], ["card","Lobos vs Toros","Sáb 14 nov · 16:00 · Cancha 1","Liga Bajío · Jornada 3","PROGRAMADO"]]
    return els

F = {}
# ───────────── Todos los usuarios ─────────────
F["C-01"] = [
 S("Bienvenida", [["brand"],["h1","Tu torneo de rugby, en una app"],["p","Equipos, torneos y resultados de tu comunidad."],["btn","Crear cuenta","pri",1],["btn","Ya tengo cuenta","sec"]], "Toca «Crear cuenta»", tab=None),
 S("Registro", [["h1","Crea tu cuenta"],["btn","Continuar con Apple","apple"],["btn","Continuar con Google","sec"],["note","o con tu correo"],["field","Nombre completo","Daniela Ruiz"],["field","Correo","daniela@correo.com"],["field","Contraseña (mín. 10)","••••••••••"],["check","Acepto el Aviso de Privacidad (LFPDPPP)",1],["btn","Crear cuenta","pri",1]], "Envía el formulario", tab=None, back="Bienvenida"),
 S("Verifica tu correo", [["done","Revisa tu correo","Te enviamos un enlace a daniela@correo.com para activar tu cuenta."],["btn","Abrir correo","pri",1],["btn","Reenviar enlace","txt"]], "Abre el enlace → la sesión inicia", tab=None),
 S("Sesión iniciada", [["done","¡Listo, Daniela!","Tu cuenta está activa. Ahora crea tu perfil (C-03)."],["btn","Crear mi perfil","pri"]], None, tab=None),
]
F["C-02"] = [
 S("Iniciar sesión", [["brand"],["h1","Bienvenida de nuevo"],["field","Correo","daniela@correo.com"],["field","Contraseña","••••••••••"],["btn","Iniciar sesión","pri",1],["btn","¿Olvidaste tu contraseña?","txt"]], "Toca «Iniciar sesión»", tab=None),
 S("Inicio", home("Daniela","Rugby Querétaro",["Torneos","Mi equipo","Partidos","Perfil"],3), "Perfil → Ajustes"),
 S("Ajustes de cuenta", [["h1","Ajustes"],["row","DR","Daniela Ruiz","daniela@correo.com","›"],["kv",[["Notificaciones","Activadas"],["Idioma","Español"]]],["btn","Cambiar contraseña","sec"],["btn","Cerrar sesión","danger",1]], "Toca «Cerrar sesión»", tab="Perfil"),
 S("Confirmar cierre", [["h1","Ajustes"],["sheet","¿Cerrar sesión?"],["p","Se borrarán los datos guardados en este teléfono."],["btn","Cerrar sesión","danger",1],["btn","Cancelar","txt"]], None, tab="Perfil"),
]
F["C-03"] = [
 S("Crear perfil", [["h1","Crea tu perfil"],["avatar","DR","Agregar foto","Opcional"],["field","Nombre","Daniela Ruiz"],["field","Fecha de nacimiento","12/03/1998"],["field","Comunidad","Rugby Querétaro"],["btn","Continuar","pri",1]], "Toca «Continuar»", tab=None),
 S("¿Cómo participas?", [["h1","¿Cómo participas?"],["p","Elige uno o varios. Puedes cambiarlo después."],["chips",["Fan","Jugador","Entrenador","Manager","Árbitro","Padre / Tutor"],[0,1]],["lock","Médico","Lo asigna un administrador de tu comunidad."],["btn","Guardar perfil","pri",1]], "Toca «Guardar perfil»", tab=None, back="Crear perfil"),
 S("Mi perfil", [["avatar","DR","Daniela Ruiz","Rugby Querétaro"],["chips",["Fan","Jugador"],[0,1]],["section","Siguientes pasos"],["row","JG","Completa tus datos de jugador","C-04","›"],["row","EQ","Únete a un equipo","E-02","›"]], None, tab="Perfil"),
]
F["C-07"] = [
 S("Comunidad", [["h1","Comunidad"],["search","Buscar por nombre, tipo o equipo",1],["section","Sugeridos"],["row","LB","Lobos de Querétaro","Equipo · XV","›"],["row","RD","Roberto Díaz","Árbitro","›"]], "Escribe «Bravo»", tab="Equipos"),
 S("Resultados", [["search","Bravo"],["chips",["Todos","Jugadores","Staff","Equipos"],[1]],["row","NB","Nicolás Bravo","Jugador · Lobos","›",1],["row","AB","Ana Bravo","Fan","›"],["note","Los menores solo aparecen para su tutor y el staff de su equipo."]], "Toca un perfil", tab="Equipos"),
 S("Perfil público", [["avatar","NB","Nicolás Bravo","Medio scrum · Lobos"],["stat",[["3","Partidos"],["2","Ensayos"],["10","Puntos"]]],["btn","Seguir","sec"]], None, tab="Equipos", back="Resultados"),
]
F["F-03"] = [
 S("Inicio", home("Daniela","Rugby Querétaro",["Torneos","Mi equipo","Partidos","Feed"],3), "Toca «Feed»"),
 S("Feed del torneo", [["h1","Liga Bajío 2027"],["seg",["Feed","Tabla","Fixture"],"Feed"],["card","Final: Lobos 28 – 17 Toros","Hace 20 min","Resultado oficial","FINAL",1],["card","Cambio de cancha J4","Hace 2 h","Anuncio del Director",""],["card","Halcones 21 – 21 Jaguares","Ayer","Resultado oficial","FINAL"]], "Toca un resultado", tab="Torneos"),
 S("Resumen del partido", [["score","LOBOS","28","TOROS","17","Final","2T"],["section","Momentos"],["event","63'","Ensayo · Lobos","#14 P. Gil","ok"],["event","52'","Amarilla · Toros","#4 J. Soto","yellow"]], None, tab="Torneos", back="Feed"),
]
# ───────────── Fan ─────────────
F["F-01"] = [
 S("Torneo", [["h1","Liga Bajío 2027"],["p","XV · 8 equipos"],["btn","Seguir torneo","pri",1],["seg",["Fixture","Tabla","Equipos"],"Equipos"],["row","LB","Lobos","8 jugadores siguen","☆"],["row","TR","Toros","","☆"]], "Toca «Seguir torneo»", tab="Torneos"),
 S("Siguiendo", [["toast","Ahora sigues Liga Bajío 2027"],["h1","Siguiendo"],["seg",["Torneos","Equipos","Jugadores"],"Torneos"],["row","LB","Liga Bajío 2027","XV · En curso","★",1]], "Ve lo que sigues en Inicio", tab="Perfil"),
 S("Inicio personalizado", home("Ana","Lo que sigues",["Torneos","Partidos","Siguiendo","Tabla"],None,[["section","De lo que sigues"],["card","Lobos vs Toros","EN VIVO · 2T 54'","21 – 14","EN VIVO"]]), None),
]
F["V-06"] = [
 S("Inicio", home("Ana","Lo que sigues",["Torneos","Partidos","Siguiendo","Tabla"],None,[["section","En vivo"],["card","Lobos vs Toros","2T 54'","21 – 14","EN VIVO",1]]), "Toca el partido en vivo"),
 S("Marcador en vivo", [["score","LOBOS","21","TOROS","14","54:12","2T"],["badge","EN VIVO","live"],["section","Minuto a minuto"],["event","54'","Ensayo · Lobos","#9 N. Bravo","ok"],["event","52'","Amarilla · Toros","#4 J. Soto · vuelve 62'","yellow"],["note","Se actualiza solo en menos de 3 s (RNF-05)."]], None, tab="Partido", back="Inicio"),
]
F["F-02"] = [
 S("Ajustes de avisos", [["h1","Notificaciones"],["check","Inicio de partido",1],["check","Ensayos",1],["check","Resultado final",1],["check","Anuncios del torneo",0],["btn","Guardar","pri",1]], "Activa los avisos", tab="Perfil"),
 S("Pantalla bloqueada", [["notif","Rugby App · ahora","¡Ensayo de Lobos! 21 – 14 · 54'"],["notif","Rugby App · hace 1 h","Empezó Lobos vs Toros"]], "Toca la notificación", tab=None, dark=True),
 S("Marcador en vivo", [["score","LOBOS","21","TOROS","14","54:12","2T"],["event","54'","Ensayo · Lobos","#9 N. Bravo","ok"]], None, tab="Partido"),
]
F["M-01"] = [
 S("Torneos", [["h1","Torneos"],["card","Liga Bajío 2027","XV · Jornada 3 de 7","8 equipos","EN CURSO",1],["card","Copa Seven","7s · Inscripciones","12 equipos","INSCRIPCIÓN"]], "Toca el torneo", tab="Torneos"),
 S("Tabla de posiciones", [["h1","Liga Bajío 2027"],["seg",["Fixture","Tabla","Equipos"],"Tabla"],["table",["#","Equipo","PJ","Dif","Pts"],[["1","Lobos","3","+41","14"],["2","Águilas","3","+18","10"],["3","Toros","3","+9","9"],["4","Halcones","3","−4","6"],["5","Jaguares","3","−12","5"],["6","Osos","3","−21","1"]]],["note","Victoria 4 · Empate 2 · Bonus por 4 ensayos o perder por 7 o menos."]], None, tab="Torneos", back="Torneos"),
]
F["M-03"] = [
 S("Equipo", [["h1","Lobos de Querétaro"],["seg",["Plantilla","Partidos","Stats"],"Plantilla"],["row","NB","Nicolás Bravo","Medio scrum · #9","›",1],["row","CR","Carlos Ruiz","Apertura · #10","›"]], "Toca un jugador", tab="Equipos"),
 S("Estadísticas del jugador", [["avatar","NB","Nicolás Bravo","Medio scrum · Lobos"],["stat",[["3","PJ"],["2","Ensayos"],["10","Puntos"]]],["stat",[["1","Amarillas"],["0","Rojas"],["212'","Minutos"]]],["section","Por partido"],["row","J3","Lobos 28 – 17 Toros","1 ensayo · 80'","5 pts"]], None, tab="Equipos", back="Lobos"),
]
F["M-04"] = [
 S("Torneo", [["h1","Liga Bajío 2027"],["seg",["Tabla","Líderes","Fixture"],"Líderes",1]], "Toca «Líderes»", tab="Torneos"),
 S("Líderes", [["h1","Líderes"],["seg",["Puntos","Ensayos","Tarjetas"],"Ensayos"],["table",["#","Jugador","Equipo","Ens."],[["1","P. Gil","Lobos","6"],["2","R. Díaz","Toros","5"],["3","N. Bravo","Lobos","4"],["4","L. Soto","Águilas","4"]]],["section","Equipos"],["stat",[["Lobos","Más ensayos"],["Águilas","Mejor defensa"]]]], None, tab="Torneos"),
]
# ───────────── Jugador ─────────────
F["C-04"] = [
 S("Mi perfil", [["avatar","NB","Nicolás Bravo","Jugador"],["row","JG","Datos de jugador","Incompletos","›",1]], "Toca «Datos de jugador»", tab="Perfil"),
 S("Datos de jugador", [["h1","Datos de jugador"],["field","Posición","Medio scrum",1],["field","Fecha de nacimiento","04/06/2001"],["field","Altura","1.74 m"],["field","Peso","72 kg"],["btn","Guardar","pri",1]], "Toca «Guardar»", tab="Perfil", back="Perfil"),
 S("Datos guardados", [["toast","Tus datos se guardaron"],["avatar","NB","Nicolás Bravo","Medio scrum · 24 años"],["kv",[["Elegibilidad","Mayor varonil"],["Estado","Completo"]]]], None, tab="Perfil"),
]
F["E-02"] = [
 S("Buscar equipo", [["h1","Únete a un equipo"],["search","Buscar equipo"],["row","LB","Lobos de Querétaro","XV · Varonil · 28 miembros","›",1],["row","TR","Toros","XV · Varonil","›"]], "Toca el equipo", tab="Equipos"),
 S("Solicitar unirme", [["h1","Lobos de Querétaro"],["p","¿Con qué rol te unes?"],["chips",["Jugador","Entrenador","Manager","Médico"],[0]],["btn","Enviar solicitud","pri",1]], "Toca «Enviar solicitud»", tab="Equipos", back="Buscar"),
 S("Solicitud enviada", [["done","Solicitud enviada","El staff de Lobos la revisará (E-03). Te avisaremos."],["badge","PENDIENTE","warn"]], None, tab="Equipos"),
]
F["E-04"] = [
 S("Mi equipo", [["h1","Lobos de Querétaro"],["seg",["Plantilla","Partidos","Stats"],"Plantilla",1],["section","Staff"],["row","JL","Jorge López","Entrenador","›"],["row","SR","Sofía Ramírez","Médico","›"],["section","Jugadores (28)"],["row","AL","Andrés López","Pilar · #1","›"],["row","NB","Nicolás Bravo","Medio scrum · #9","›"]], None, tab="Equipos"),
]
# ───────────── Padre / Tutor ─────────────
F["C-05"] = [
 S("Mi perfil", [["avatar","LH","Laura Hernández","Padre / Tutor"],["row","+","Vincular a mi hijo","Menor de 18 años","›",1]], "Toca «Vincular a mi hijo»", tab="Perfil"),
 S("Buscar a tu hijo", [["h1","Vincular menor"],["field","Nombre del menor","Mateo Hernández"],["field","Fecha de nacimiento","10/02/2011"],["field","Parentesco","Madre"],["check","Autorizo su participación y el tratamiento de sus datos (LFPDPPP)",1],["btn","Enviar solicitud","pri",1]], "Envía la solicitud", tab="Perfil", back="Perfil"),
 S("En validación", [["done","Solicitud enviada","Un administrador de la comunidad validará la tutela."],["badge","PENDIENTE","warn"]], "El administrador aprueba", tab="Perfil"),
 S("Perfil del menor", [["avatar","MH","Mateo Hernández","15 años · Lobos"],["badge","TUTOR VALIDADO","ok"],["kv",[["Elegible","Sí"],["Aptitud médica","Apto"]]],["row","PJ","Próximo partido","Sáb 14 nov · 16:00","›"]], None, tab="Perfil"),
]
# ───────────── Entrenador / Manager ─────────────
F["E-01"] = [
 S("Equipos", [["h1","Equipos"],["p","Aún no tienes equipo."],["btn","Crear equipo","pri",1]], "Toca «Crear equipo»", tab="Equipos"),
 S("Nuevo equipo", [["h1","Nuevo equipo"],["avatar","+","Escudo","PNG o JPG"],["field","Nombre","Lobos de Querétaro"],["field","Comunidad","Rugby Querétaro"],["chips",["Mayor varonil","Femenil","Juvenil"],[0]],["btn","Crear equipo","pri",1]], "Toca «Crear equipo»", tab="Equipos", back="Equipos"),
 S("Equipo creado", [["done","¡Lobos creado!","Comparte el equipo para que jugadores y staff soliciten unirse (E-02)."],["btn","Compartir enlace","sec"]], None, tab="Equipos"),
]
F["E-03"] = [
 S("Mi equipo", [["h1","Lobos de Querétaro"],["seg",["Plantilla (28)","Solicitudes (3)"],"Solicitudes (3)",1]], "Toca «Solicitudes»", tab="Equipos"),
 S("Solicitudes", [["h1","Solicitudes"],["row","DM","Diego Martínez","Jugador · 24 años","PENDIENTE",1],["row","SR","Sofía Ramírez","Médico","PENDIENTE"],["row","MH","Mateo Hernández","Jugador · 15 años · tutor validado","PENDIENTE"]], "Toca una solicitud", tab="Equipos", back="Equipo"),
 S("Revisar solicitud", [["avatar","DM","Diego Martínez","Jugador · 24 años"],["kv",[["Posición","Ala"],["Datos de jugador","Completos"]]],["btn","Aprobar","pri",1],["btn","Rechazar","sec"]], "Toca «Aprobar»", tab="Equipos", back="Solicitudes"),
 S("Aprobada", [["toast","Diego se unió a Lobos"],["h1","Solicitudes"],["row","SR","Sofía Ramírez","Médico","PENDIENTE"]], None, tab="Equipos"),
]
F["O-04"] = [
 S("Torneos de mi equipo", [["h1","Liga Bajío 2027"],["card","Plantilla para el torneo","Fecha límite: 7 nov","0 de 30 registrados","PENDIENTE",1]], "Toca «Plantilla»", tab="Torneos"),
 S("Elegir jugadores", [["h1","Plantilla del torneo"],["search","Buscar en mi equipo"],["check","1 · Andrés López · elegible",1],["check","9 · Nicolás Bravo · elegible",1],["check","12 · Mateo Hernández · falta tutor",0],["btn","Registrar 23 jugadores","pri",1]], "Toca «Registrar»", tab="Torneos", back="Torneo"),
 S("Plantilla registrada", [["done","Plantilla registrada","23 jugadores elegibles. 1 pendiente por autorización del tutor."]], None, tab="Torneos"),
]
F["P-02"] = [
 S("Partido", [["card","Lobos vs Toros","Sáb 14 nov · 16:00","Alineación pendiente","PRE",0],["btn","Capturar alineación","pri",1]], "Toca «Capturar alineación»", tab="Partido"),
 S("Alineación", [["h1","Alineación"],["stat",[["15/15","Titulares"],["7/8","Suplentes"]]],["row","1","Andrés López","Pilar izquierdo","✓"],["row","9","Nicolás Bravo","Medio scrum","✓"],["row","12","Mateo Hernández","No elegible: falta tutor","!"],["btn","Confirmar alineación","pri",1]], "Toca «Confirmar»", tab="Partido", back="Partido"),
 S("Alineación enviada", [["done","Alineación confirmada","El árbitro la verá en el check-in (P-03)."]], None, tab="Partido"),
]
F["R-02"] = [
 S("Partido cerrado", [["score","LOBOS","28","TOROS","17","Final","2T"],["btn","Ver reporte","pri",1]], "Toca «Ver reporte»", tab="Partido"),
 S("Vista previa", [["h1","Reporte del partido"],["pdf"],["btn","Compartir PDF","pri",1]], "Toca «Compartir PDF»", tab="Partido", back="Partido"),
 S("Compartir", [["h1","Reporte del partido"],["sheet","Compartir"],["row","WA","WhatsApp","","›"],["row","@","Correo","","›"],["row","⤓","Guardar en Archivos","","›"]], None, tab="Partido"),
]
# ───────────── Médico ─────────────
F["C-06"] = [
 S("Mi equipo", [["h1","Lobos · Médico"],["row","MH","Mateo Hernández","Apto · última revisión 2 oct","›",1],["row","NB","Nicolás Bravo","Apto con restricciones","›"]], "Toca un jugador", tab="Equipos"),
 S("Ficha médica", [["avatar","MH","Mateo Hernández","15 años · tutor validado"],["badge","DATOS SENSIBLES","warn"],["kv",[["Aptitud","Apto"],["Alergias","Ninguna"]]],["btn","Registrar revisión","pri",1]], "Toca «Registrar revisión»", tab="Equipos", back="Equipo"),
 S("Nueva revisión", [["h1","Nueva revisión"],["chips",["Apto","Con restricciones","No apto"],[2]],["field","Lesión","Esguince de tobillo derecho"],["field","Regreso estimado","2 semanas"],["btn","Guardar","pri",1]], "Toca «Guardar»", tab="Equipos", back="Ficha"),
 S("Registrada", [["toast","Revisión guardada · el entrenador solo ve «No apto»"],["avatar","MH","Mateo Hernández",""],["badge","NO APTO","danger"]], None, tab="Equipos"),
]
F["R-03"] = [
 S("Partido cerrado", [["score","LOBOS","28","TOROS","17","Final","2T"],["btn","Registrar lesión","sec",1]], "Toca «Registrar lesión»", tab="Partido"),
 S("Lesión en partido", [["h1","Lesión"],["field","Jugador","#12 · M. Hernández"],["field","Minuto","38'"],["field","Descripción","Golpe en hombro"],["chips",["Puede seguir","Salió del partido"],[1]],["btn","Guardar","pri",1]], "Toca «Guardar»", tab="Partido", back="Partido"),
 S("Reporte médico", [["done","Reporte médico guardado","Visible solo para el médico, el jugador y su tutor."]], None, tab="Partido"),
]
# ───────────── Árbitro / Anotador ─────────────
F["P-03"] = [
 S("Mis partidos", [["h1","Mis partidos"],["card","Lobos vs Toros","Hoy · 16:00 · Cancha 1","Árbitro central","PRE",1]], "Toca el partido", tab="Partido"),
 S("Check-in", [["h1","Check-in"],["check","Alineación Lobos (23)",1],["check","Alineación Toros (22)",1],["check","Oficiales presentes",1],["check","Cancha en condiciones",1],["btn","Generar reporte pre-partido","pri",1]], "Toca «Generar reporte»", tab="Partido", back="Partidos"),
 S("Listo para iniciar", [["done","Partido listo","Reporte pre-partido firmado. Ya puedes iniciar el reloj (V-01)."],["btn","Ir al partido","pri"]], None, tab="Partido"),
]
F["V-01"] = [
 S("Partido · antes del inicio", [["score","LOBOS","0","TOROS","0","00:00","1T"],["btn","Iniciar 1er tiempo","pri",1]], "Toca «Iniciar»", tab=None, dark=True),
 S("Reloj corriendo", [["score","LOBOS","0","TOROS","0","12:34","1T"],["btn","Pausar","sec",1],["btn","Fin del tiempo","txt"]], "Pausa o termina el tiempo", tab=None, dark=True),
 S("Medio tiempo", [["score","LOBOS","14","TOROS","7","40:00","MT"],["btn","Iniciar 2º tiempo","pri"]], None, tab=None, dark=True),
]
F["V-02"] = [
 S("Partido en vivo", [["score","LOBOS","14","TOROS","14","53:40","2T"],["seg",["LOBOS","TOROS"],"LOBOS"],["grid",[["ENSAYO","+5"],["CONVERSIÓN","+2"],["PENAL","+3"],["DROP","+3"]],0]], "Toca «ENSAYO»", tab=None, dark=True),
 S("¿Quién anotó?", [["score","LOBOS","14","TOROS","14","53:40","2T"],["sheet","Ensayo · Lobos · 54'"],["row","9","Nicolás Bravo","Medio scrum","",1],["row","14","Pedro Gil","Ala",""],["row","10","Carlos Ruiz","Apertura",""]], "Toca al jugador", tab=None, dark=True),
 S("Ensayo registrado", [["score","LOBOS","19","TOROS","14","54:12","2T"],["toast","54' · Ensayo de Lobos · #9 · Anular"],["grid",[["ENSAYO","+5"],["CONVERSIÓN","+2"],["PENAL","+3"],["DROP","+3"]],None]], None, tab=None, dark=True),
]
F["V-03"] = [
 S("Partido en vivo", [["score","LOBOS","19","TOROS","14","51:00","2T"],["seg",["LOBOS","TOROS"],"TOROS"],["cards",["AMARILLA","ROJA","CAMBIO"],0]], "Toca «AMARILLA»", tab=None, dark=True),
 S("Jugador sancionado", [["score","LOBOS","19","TOROS","14","51:00","2T"],["sheet","Amarilla · Toros · 52'"],["row","4","Juan Soto","Segunda línea","",1],["row","7","Luis Mora","Ala",""]], "Toca al jugador", tab=None, dark=True),
 S("Toros con 14", [["score","LOBOS","19","TOROS","14","52:10","2T"],["banner","Toros juega con 14 · #4 vuelve al 62'"],["cards",["AMARILLA","ROJA","CAMBIO"],None]], None, tab=None, dark=True),
]
F["V-04"] = [
 S("Partido en vivo", [["score","LOBOS","21","TOROS","17","50:00","2T"],["toast","49' · Penal de Toros · Anular",1]], "Toca «Anular»", tab=None, dark=True),
 S("Línea de tiempo", [["h1","Línea de tiempo"],["event","49'","Penal · Toros","#10 R. Díaz · +3","ok",1],["event","47'","Penal · Toros","#10 R. Díaz · +3","ok"],["event","41'","Conversión · Lobos","#10 C. Ruiz · +2","ok"],["btn","Anular evento seleccionado","danger",1]], "Confirma la anulación", tab=None, dark=True, back="Partido"),
 S("Evento anulado", [["event","49'","Penal · Toros","ANULADO · árbitro, 50'","void"],["event","47'","Penal · Toros","#10 R. Díaz · +3","ok"],["note","No se borra: queda en el acta con quién y cuándo (RNF-13)."]], None, tab=None, dark=True),
]
F["V-05"] = [
 S("Sin señal", [["score","LOBOS","19","TOROS","14","54:12","2T"],["banner","Sin conexión · 3 eventos por enviar"],["grid",[["ENSAYO","+5"],["CONVERSIÓN","+2"],["PENAL","+3"],["DROP","+3"]],1]], "Sigue registrando sin señal", tab=None, dark=True),
 S("Vuelve la señal", [["score","LOBOS","21","TOROS","14","56:02","2T"],["toast","Conexión recuperada · 4 eventos enviados"],["note","Se envían en orden y sin duplicados (SP-02)."]], None, tab=None, dark=True),
]
F["R-01"] = [
 S("Fin del partido", [["score","LOBOS","28","TOROS","17","80:00","FIN"],["btn","Cerrar partido","pri",1]], "Toca «Cerrar partido»", tab=None, dark=True),
 S("Validar", [["h1","Cerrar partido"],["check","87 de 87 eventos sincronizados",1],["check","El servidor obtiene 28 – 17",1],["check","1 amarilla · 0 rojas",1],["sig"],["btn","Firmar y cerrar","pri",1]], "Firma y cierra", tab="Partido", back="Partido"),
 S("Resultado oficial", [["done","Resultado oficial","Lobos 28 – 17 Toros. La tabla se actualiza (M-01) y se notifica a los seguidores (F-02)."]], None, tab="Partido"),
]
F["R-04"] = [
 S("Partido cerrado", [["score","LOBOS","28","TOROS","17","Final","2T"],["banner","1 tarjeta roja sin informe"],["btn","Redactar informe","pri",1]], "Toca «Redactar informe»", tab="Partido"),
 S("Informe disciplinario", [["h1","Informe · Roja"],["field","Jugador","#6 · T. Vega (Toros)"],["field","Minuto","66'"],["field","Hecho","Tackle alto con contacto en la cabeza"],["sig"],["btn","Enviar al comité","pri",1]], "Toca «Enviar»", tab="Partido", back="Partido"),
 S("Enviado", [["done","Informe enviado","Lo verá el Director de Competencia y el comité disciplinario."]], None, tab="Partido"),
]
# ───────────── Administrador de Torneo ─────────────
F["O-03"] = [
 S("Torneo", [["h1","Liga Bajío 2027"],["seg",["Equipos","Fixture","Oficiales"],"Equipos"],["p","0 equipos inscritos"],["btn","Inscribir equipos","pri",1]], "Toca «Inscribir equipos»", tab="Torneos"),
 S("Elegir equipos", [["h1","Inscribir equipos"],["search","Buscar en Rugby Querétaro"],["check","Lobos",1],["check","Toros",1],["check","Halcones",1],["check","Jaguares",0],["btn","Inscribir 3 equipos","pri",1]], "Toca «Inscribir»", tab="Torneos", back="Torneo"),
 S("Inscritos", [["toast","3 equipos inscritos · se avisó a sus managers (O-04)"],["row","LB","Lobos","Plantilla pendiente","›"],["row","TR","Toros","Plantilla pendiente","›"]], None, tab="Torneos"),
]
F["O-05"] = [
 S("Torneo", [["h1","Liga Bajío 2027"],["seg",["Equipos","Fixture","Oficiales"],"Fixture"],["p","8 equipos inscritos · sin calendario"],["btn","Generar calendario","pri",1]], "Toca «Generar calendario»", tab="Torneos"),
 S("Opciones", [["h1","Generar calendario"],["chips",["Todos contra todos","Grupos + finales"],[0]],["field","Inicio","Sáb 31 oct"],["field","Canchas","Cancha 1, Cancha 2"],["btn","Generar","pri",1]], "Toca «Generar»", tab="Torneos", back="Torneo"),
 S("Calendario", [["h1","Fixture"],["section","Jornada 1 · Sáb 31 oct"],["card","Lobos vs Toros","16:00 · Cancha 1","Sin oficiales","PROGRAMADO"],["card","Halcones vs Jaguares","18:00 · Cancha 2","Sin oficiales","PROGRAMADO"],["btn","Publicar","pri"]], None, tab="Torneos"),
]
F["P-01"] = [
 S("Fixture", [["h1","Fixture"],["card","Lobos vs Toros","Sáb 14 nov · 16:00","Sin oficiales","PROGRAMADO",1]], "Toca el partido", tab="Torneos"),
 S("Asignar oficiales", [["h1","Oficiales"],["field","Árbitro central","Roberto Díaz",1],["field","Anotador","Elena Cruz"],["field","Juez de línea","—"],["btn","Guardar","pri",1]], "Toca «Guardar»", tab="Torneos", back="Fixture"),
 S("Asignados", [["toast","Se avisó a los oficiales"],["card","Lobos vs Toros","Sáb 14 nov · 16:00","R. Díaz · E. Cruz","LISTO"]], None, tab="Torneos"),
]
# ───────────── Director de Competencia ─────────────
F["O-01"] = [
 S("Mi comunidad", [["h1","Rugby Querétaro"],["p","Director de Competencia"],["btn","Nuevo torneo","pri",1],["section","Torneos"],["card","Copa Seven","7s","Inscripciones","INSCRIPCIÓN"]], "Toca «Nuevo torneo»", tab="Torneos"),
 S("Nuevo torneo", [["h1","Nuevo torneo"],["field","Nombre","Liga Bajío 2027"],["chips",["Sevens","Tens","Rugby 13","XV","Festival"],[3]],["kv",[["Ensayo","5 pts"],["Tiempos","2 × 40 min"],["Amarilla","10 min"]]],["btn","Crear torneo","pri",1]], "Toca «Crear torneo»", tab="Torneos", back="Comunidad"),
 S("Torneo creado", [["done","Liga Bajío 2027","Creado con las reglas de XV. Ajústalas (O-02) y nombra administradores (A-02)."]], None, tab="Torneos"),
]
F["O-02"] = [
 S("Torneo", [["h1","Liga Bajío 2027"],["row","⚙","Reglas del torneo","XV · por defecto","›",1]], "Toca «Reglas»", tab="Torneos"),
 S("Reglas", [["h1","Reglas"],["kv",[["Victoria","4"],["Empate","2"],["Bonus ofensivo","4 ensayos"],["Bonus defensivo","≤ 7"]]],["field","Minutos por tiempo","35",1],["btn","Guardar","pri",1]], "Toca «Guardar»", tab="Torneos", back="Torneo"),
 S("Guardadas", [["toast","Reglas actualizadas para Liga Bajío 2027"]], None, tab="Torneos"),
]
F["O-06"] = [
 S("Nuevo torneo", [["h1","Nuevo torneo"],["chips",["Sevens","Tens","Rugby 13","XV","Festival"],[4],4]], "Elige «Festival»", tab="Torneos"),
 S("Festival", [["h1","Festival infantil"],["field","Categoría","Sub-10"],["note","Los festivales no llevan marcador ni tabla: solo registran participación."],["btn","Crear festival","pri",1]], "Toca «Crear festival»", tab="Torneos", back="Nuevo"),
 S("Festival creado", [["done","Festival Sub-10","Los partidos registran asistencia, sin marcador."]], None, tab="Torneos"),
]
F["A-02"] = [
 S("Torneo", [["h1","Liga Bajío 2027"],["row","AD","Administradores","Ninguno","›",1]], "Toca «Administradores»", tab="Torneos"),
 S("Nombrar administrador", [["h1","Administradores"],["search","Buscar en la comunidad"],["row","EC","Elena Cruz","Rugby Querétaro","Añadir",1]], "Toca «Añadir»", tab="Torneos", back="Torneo"),
 S("Nombrado", [["toast","Elena Cruz ya administra Liga Bajío 2027"],["row","EC","Elena Cruz","Administradora","✓"]], None, tab="Torneos"),
]
F["M-02"] = [
 S("Reglas", [["h1","Reglas"],["row","≡","Orden de desempate","Por defecto","›",1]], "Toca «Orden de desempate»", tab="Torneos"),
 S("Desempate", [["h1","Orden de desempate"],["row","1","Puntos","","≡"],["row","2","Diferencia de puntos","","≡"],["row","3","Ensayos a favor","","≡"],["row","4","Enfrentamiento directo","","≡"],["btn","Guardar orden","pri",1]], "Arrastra y guarda", tab="Torneos", back="Reglas"),
 S("Aplicado", [["toast","La tabla se recalculó con el nuevo orden"]], None, tab="Torneos"),
]
# ───────────── MasterUser ─────────────
F["A-01"] = [
 S("Mi comunidad", [["h1","Rugby Querétaro"],["p","MasterUser"],["row","DC","Directores de Competencia","1","›",1]], "Toca «Directores»", tab="Inicio"),
 S("Nombrar director", [["h1","Directores"],["search","Buscar perfil"],["row","JM","Jaime Morales","Rugby Querétaro","Nombrar",1]], "Toca «Nombrar»", tab="Inicio", back="Comunidad"),
 S("Confirmar", [["h1","Directores"],["sheet","¿Nombrar a Jaime Morales?"],["p","Podrá crear torneos y nombrar administradores."],["btn","Nombrar director","pri",1]], "Confirma", tab="Inicio"),
 S("Nombrado", [["toast","Jaime Morales es Director de Competencia"],["row","JM","Jaime Morales","Director","✓"]], None, tab="Inicio"),
]

N = json.load(open(os.path.join(os.path.dirname(__file__), "notion.json")))
AN = N.pop("_AN")
stories = {}
for k, v in N.items():
    url, como, quiero, para, sprint, prio, ver, pts = v
    stories[k] = {"id":k,"notion":url,"android":AN.get(k),"como":como,"quiero":quiero,"para":para,"sprint":sprint,
                  "prio":prio,"ver":ver,"pts":pts,"act":ACT[k[0]],"deps":DEPS[k],"flow":F[k]}
missing = [k for r in ROLES for k in r[2] if k not in F]
assert not missing, missing
assert set(F) == set(stories), set(F) ^ set(stories)
data = {"roles":[{"name":n,"desc":d,"hus":h} for n,d,h in ROLES], "stories":stories}
out = os.path.join(os.path.dirname(__file__), "..", "data.js")
open(out,"w").write("// Generado por build/flows.py — no editar a mano\nconst DATA = " + json.dumps(data, ensure_ascii=False) + ";\n")
n_screens = sum(len(F[k]) for r in ROLES for k in r[2])
print("historias:", len(stories), "pantallas en páginas de rol:", n_screens)
