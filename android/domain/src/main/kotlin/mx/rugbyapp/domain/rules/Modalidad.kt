package mx.rugbyapp.domain.rules

/**
 * SP-01 · Motor de reglas por modalidad.
 * Fuente de verdad: docs/domain-model.md §2. Espejo en iOS: Domain/Rules/Modalidad.swift
 *
 * Los valores marcados como "por validar" en docs/spikes/SP-01.md se confirman con el socio;
 * por eso viven en ReglasDeModalidad (configurable) y no como constantes dispersas.
 */
enum class Modalidad(val codigo: String) {
    SEVENS("7"),
    TENS("10"),
    LEAGUE13("13"),
    FIFTEENS("15"),
    FESTIVAL("festival");

    companion object {
        fun desdeCodigo(codigo: String): Modalidad =
            entries.firstOrNull { it.codigo == codigo }
                ?: throw IllegalArgumentException("Modalidad desconocida: $codigo")
    }
}

/** Puntos por tipo de anotación. null = la anotación no existe en la modalidad. */
data class Puntuacion(
    val ensayo: Int?,
    val conversion: Int?,
    val penal: Int?,
    val drop: Int?,
    val ensayoDePenal: Int?
)

data class ReglasDeModalidad(
    val modalidad: Modalidad,
    val jugadoresEnCancha: Int,
    val tiempos: Int,
    val minutosPorTiempo: Int,
    val minutosExpulsionTemporal: Int,
    val cambiosPermitidos: Int,
    val puntuacion: Puntuacion,
    /** Los festivales infantiles no llevan marcador ni cuentan para la tabla. */
    val llevaMarcador: Boolean
) {
    companion object {
        private val UNION = Puntuacion(ensayo = 5, conversion = 2, penal = 3, drop = 3, ensayoDePenal = 7)
        private val LEAGUE = Puntuacion(ensayo = 4, conversion = 2, penal = 2, drop = 1, ensayoDePenal = null)
        private val SIN_MARCADOR = Puntuacion(null, null, null, null, null)

        fun porDefecto(modalidad: Modalidad): ReglasDeModalidad = when (modalidad) {
            Modalidad.FIFTEENS -> ReglasDeModalidad(modalidad, 15, 2, 40, 10, 8, UNION, true)
            Modalidad.TENS -> ReglasDeModalidad(modalidad, 10, 2, 10, 2, 5, UNION, true)
            Modalidad.SEVENS -> ReglasDeModalidad(modalidad, 7, 2, 7, 2, 5, UNION, true)
            Modalidad.LEAGUE13 -> ReglasDeModalidad(modalidad, 13, 2, 40, 10, 8, LEAGUE, true)
            Modalidad.FESTIVAL -> ReglasDeModalidad(modalidad, 7, 2, 10, 0, 99, SIN_MARCADOR, false)
        }
    }

    fun puntosDe(tipo: TipoEvento): Int? = when (tipo) {
        TipoEvento.ENSAYO -> puntuacion.ensayo
        TipoEvento.CONVERSION -> puntuacion.conversion
        TipoEvento.PENAL -> puntuacion.penal
        TipoEvento.DROP -> puntuacion.drop
        TipoEvento.ENSAYO_DE_PENAL -> puntuacion.ensayoDePenal
        else -> 0
    }
}
