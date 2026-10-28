package mx.rugbyapp.domain.rules

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

/**
 * Contrato del motor de reglas (SP-01). Los mismos casos existen en
 * ios/Packages/Domain/Tests/DomainTests/MotorDePartidoTests.swift: si pasan en ambas, el port es correcto.
 * Casos de prueba: CP-120 a CP-127.
 */
class MotorDePartidoTest {

    private fun motor(m: Modalidad) = MotorDePartido(ReglasDeModalidad.porDefecto(m))
    private var n = 0
    private fun ev(tipo: TipoEvento, lado: Lado = Lado.LOCAL, min: Int = 1, jugador: Int? = null, anula: String? = null) =
        EventoDePartido(id = "e${++n}", tipo = tipo, lado = lado, jugador = jugador, minuto = min, anulaA = anula)

    @Test fun `CP-120 un ensayo vale 5 en XV y en 7s`() {
        assertEquals(5, motor(Modalidad.FIFTEENS).calcular(listOf(ev(TipoEvento.ENSAYO))).local.puntos)
        assertEquals(5, motor(Modalidad.SEVENS).calcular(listOf(ev(TipoEvento.ENSAYO))).local.puntos)
    }

    @Test fun `CP-121 en rugby 13 el ensayo vale 4 y el drop 1`() {
        val e = motor(Modalidad.LEAGUE13).calcular(listOf(ev(TipoEvento.ENSAYO), ev(TipoEvento.DROP, min = 5)))
        assertEquals(5, e.local.puntos)
    }

    @Test fun `CP-122 ensayo mas conversion suma 7 y la conversion sin ensayo se rechaza`() {
        val m = motor(Modalidad.FIFTEENS)
        assertEquals(7, m.calcular(listOf(ev(TipoEvento.ENSAYO), ev(TipoEvento.CONVERSION, min = 2))).local.puntos)
        expect<ErrorDeRegla.ConversionSinEnsayo> { m.calcular(listOf(ev(TipoEvento.CONVERSION))) }
        // Un evento del rival entre el ensayo y la conversión cierra la ventana
        expect<ErrorDeRegla.ConversionSinEnsayo> {
            m.calcular(listOf(ev(TipoEvento.ENSAYO, min = 1), ev(TipoEvento.PENAL, Lado.VISITA, min = 2), ev(TipoEvento.CONVERSION, min = 3)))
        }
    }

    @Test fun `CP-123 con tarjeta roja el equipo juega con 14 el resto del partido`() {
        val e = motor(Modalidad.FIFTEENS).calcular(listOf(ev(TipoEvento.TARJETA_ROJA, jugador = 4, min = 20)), alMinuto = 80)
        assertEquals(14, e.local.enCancha)
        assertEquals(15, e.visita.enCancha)
    }

    @Test fun `CP-124 la amarilla en 7s dura 2 minutos y en XV 10`() {
        val siete = motor(Modalidad.SEVENS)
        val amarilla = listOf(ev(TipoEvento.TARJETA_AMARILLA, jugador = 3, min = 4))
        assertEquals(6, siete.calcular(amarilla, alMinuto = 5).local.enCancha)
        assertEquals(7, siete.calcular(amarilla, alMinuto = 6).local.enCancha)
        val quince = motor(Modalidad.FIFTEENS)
        assertEquals(14, quince.calcular(amarilla, alMinuto = 13).local.enCancha)
        assertEquals(15, quince.calcular(amarilla, alMinuto = 14).local.enCancha)
    }

    @Test fun `CP-125 un jugador expulsado no puede anotar`() {
        expect<ErrorDeRegla.JugadorExpulsado> {
            motor(Modalidad.FIFTEENS).calcular(listOf(
                ev(TipoEvento.TARJETA_ROJA, jugador = 9, min = 10),
                ev(TipoEvento.ENSAYO, jugador = 9, min = 30)))
        }
    }

    @Test fun `CP-126 un evento anulado no suma pero sigue en la lista (RNF-13)`() {
        val ensayo = ev(TipoEvento.ENSAYO, min = 10)
        val eventos = listOf(ensayo, ev(TipoEvento.ANULACION, min = 11, anula = ensayo.id))
        assertEquals(0, motor(Modalidad.FIFTEENS).calcular(eventos).local.puntos)
        assertEquals(2, eventos.size)
        expect<ErrorDeRegla.AnulacionInvalida> {
            motor(Modalidad.FIFTEENS).calcular(listOf(ev(TipoEvento.ANULACION, anula = "no-existe")))
        }
    }

    @Test fun `CP-127 los festivales no llevan marcador`() {
        val reglas = ReglasDeModalidad.porDefecto(Modalidad.FESTIVAL)
        assertFalse(reglas.llevaMarcador)
        expect<ErrorDeRegla.AnotacionNoPermitida> { motor(Modalidad.FESTIVAL).calcular(listOf(ev(TipoEvento.ENSAYO))) }
        expect<ErrorDeRegla.AnotacionNoPermitida> { motor(Modalidad.LEAGUE13).calcular(listOf(ev(TipoEvento.ENSAYO_DE_PENAL))) }
    }

    @Test fun `CP-128 los cambios respetan el limite de la modalidad`() {
        val cambios = (1..6).map { ev(TipoEvento.CAMBIO, min = 30 + it, jugador = it) }
        expect<ErrorDeRegla.SinCambiosDisponibles> { motor(Modalidad.SEVENS).calcular(cambios) }
        assertEquals(5, motor(Modalidad.SEVENS).calcular(cambios.take(5)).local.cambiosUsados)
    }

    @Test fun `modalidad desde codigo de base de datos`() {
        assertEquals(Modalidad.TENS, Modalidad.desdeCodigo("10"))
        expect<IllegalArgumentException> { Modalidad.desdeCodigo("12") }
    }
}

inline fun <reified T : Throwable> expect(block: () -> Unit) {
    try { block() } catch (t: Throwable) {
        if (t is T) return
        throw AssertionError("Se esperaba ${T::class.simpleName} pero se lanzó ${t::class.simpleName}: ${t.message}")
    }
    throw AssertionError("Se esperaba ${T::class.simpleName} y no se lanzó nada")
}
