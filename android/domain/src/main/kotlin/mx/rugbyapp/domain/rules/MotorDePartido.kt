package mx.rugbyapp.domain.rules

/**
 * SP-01 · Reconstruye el estado del partido a partir de su lista de eventos (event sourcing).
 * El estado nunca se guarda "a mano": siempre se deriva de match_events, así el marcador
 * es auditable (RNF-13) y el mismo cálculo corre igual en iOS, Android y backend.
 */
enum class Lado { LOCAL, VISITA }

enum class TipoEvento {
    ENSAYO, CONVERSION, PENAL, DROP, ENSAYO_DE_PENAL,
    TARJETA_AMARILLA, TARJETA_ROJA, CAMBIO, ANULACION
}

data class EventoDePartido(
    val id: String,               // UUID generado en el cliente (SP-02)
    val tipo: TipoEvento,
    val lado: Lado,
    val jugador: Int? = null,     // número de camiseta
    val jugadorQueEntra: Int? = null,
    val minuto: Int,
    val anulaA: String? = null    // solo para ANULACION
)

data class EstadoDeEquipo(
    val puntos: Int = 0,
    val enCancha: Int,
    val expulsadosDefinitivos: Set<Int> = emptySet(),
    /** jugador -> minuto en que puede regresar */
    val expulsionesTemporales: Map<Int, Int> = emptyMap(),
    val cambiosUsados: Int = 0,
    val ensayoPendienteDeConversion: Boolean = false
)

data class EstadoDePartido(val local: EstadoDeEquipo, val visita: EstadoDeEquipo) {
    fun de(lado: Lado) = if (lado == Lado.LOCAL) local else visita
    fun con(lado: Lado, e: EstadoDeEquipo) = if (lado == Lado.LOCAL) copy(local = e) else copy(visita = e)
}

sealed class ErrorDeRegla(msg: String) : Exception(msg) {
    class AnotacionNoPermitida(t: TipoEvento, m: Modalidad) : ErrorDeRegla("$t no existe en la modalidad ${m.codigo}")
    class ConversionSinEnsayo : ErrorDeRegla("Una conversión solo puede seguir a un ensayo del mismo equipo")
    class JugadorExpulsado(n: Int) : ErrorDeRegla("El jugador $n está expulsado")
    class SinCambiosDisponibles : ErrorDeRegla("El equipo ya usó todos sus cambios")
    class AnulacionInvalida(id: String) : ErrorDeRegla("No existe el evento $id para anular")
}

class MotorDePartido(private val reglas: ReglasDeModalidad) {

    fun estadoInicial() = EstadoDePartido(
        EstadoDeEquipo(enCancha = reglas.jugadoresEnCancha),
        EstadoDeEquipo(enCancha = reglas.jugadoresEnCancha)
    )

    /**
     * Calcula el estado al minuto [alMinuto]. Los eventos anulados se ignoran (no se borran).
     * Lanza ErrorDeRegla si la secuencia viola una regla de la modalidad.
     */
    fun calcular(eventos: List<EventoDePartido>, alMinuto: Int = Int.MAX_VALUE): EstadoDePartido {
        val anulados = eventos.filter { it.tipo == TipoEvento.ANULACION }.map { it.anulaA }.toSet()
        val ids = eventos.map { it.id }.toSet()
        anulados.forEach { if (it == null || it !in ids) throw ErrorDeRegla.AnulacionInvalida(it ?: "null") }

        var estado = estadoInicial()
        eventos
            .filter { it.tipo != TipoEvento.ANULACION && it.id !in anulados && it.minuto <= alMinuto }
            .sortedBy { it.minuto }
            .forEach { ev ->
                estado = regresarExpulsados(estado, ev.minuto)
                estado = aplicar(estado, ev)
            }
        return regresarExpulsados(estado, alMinuto)
    }

    private fun aplicar(estado: EstadoDePartido, ev: EventoDePartido): EstadoDePartido {
        val equipo = estado.de(ev.lado)
        ev.jugador?.let { if (it in equipo.expulsadosDefinitivos || it in equipo.expulsionesTemporales) throw ErrorDeRegla.JugadorExpulsado(it) }

        return when (ev.tipo) {
            TipoEvento.ENSAYO, TipoEvento.PENAL, TipoEvento.DROP, TipoEvento.ENSAYO_DE_PENAL, TipoEvento.CONVERSION -> {
                val puntos = reglas.puntosDe(ev.tipo)
                if (!reglas.llevaMarcador || puntos == null) throw ErrorDeRegla.AnotacionNoPermitida(ev.tipo, reglas.modalidad)
                if (ev.tipo == TipoEvento.CONVERSION && !equipo.ensayoPendienteDeConversion) throw ErrorDeRegla.ConversionSinEnsayo()
                estado.con(ev.lado, equipo.copy(
                    puntos = equipo.puntos + puntos,
                    ensayoPendienteDeConversion = ev.tipo == TipoEvento.ENSAYO
                ))
            }
            TipoEvento.TARJETA_AMARILLA -> estado.con(ev.lado, equipo.copy(
                enCancha = equipo.enCancha - 1,
                expulsionesTemporales = equipo.expulsionesTemporales + (ev.jugador!! to ev.minuto + reglas.minutosExpulsionTemporal),
                ensayoPendienteDeConversion = false
            ))
            TipoEvento.TARJETA_ROJA -> estado.con(ev.lado, equipo.copy(
                enCancha = equipo.enCancha - 1,
                expulsadosDefinitivos = equipo.expulsadosDefinitivos + ev.jugador!!,
                ensayoPendienteDeConversion = false
            ))
            TipoEvento.CAMBIO -> {
                if (equipo.cambiosUsados >= reglas.cambiosPermitidos) throw ErrorDeRegla.SinCambiosDisponibles()
                estado.con(ev.lado, equipo.copy(cambiosUsados = equipo.cambiosUsados + 1, ensayoPendienteDeConversion = false))
            }
            TipoEvento.ANULACION -> estado
        }.let { nuevo ->
            // Cualquier evento distinto a ENSAYO del otro equipo también cierra la ventana de conversión.
            val otro = if (ev.lado == Lado.LOCAL) Lado.VISITA else Lado.LOCAL
            nuevo.con(otro, nuevo.de(otro).copy(ensayoPendienteDeConversion = false))
        }
    }

    private fun regresarExpulsados(estado: EstadoDePartido, minuto: Int): EstadoDePartido {
        var e = estado
        for (lado in Lado.entries) {
            val eq = e.de(lado)
            val regresan = eq.expulsionesTemporales.filterValues { it <= minuto }
            if (regresan.isNotEmpty()) {
                e = e.con(lado, eq.copy(
                    enCancha = eq.enCancha + regresan.size,
                    expulsionesTemporales = eq.expulsionesTemporales - regresan.keys
                ))
            }
        }
        return e
    }
}
