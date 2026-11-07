package mx.rugbyapp.presentation.cuentas

import mx.rugbyapp.domain.cuentas.Sesion
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * C-01 · H-5: al rotar, Android recrea la Activity y la composición, y los `LaunchedEffect` vuelven a correr con el
 * mismo estado de los ViewModels (que sí sobreviven). [EventosDeCuenta] también sobrevive, así que la composición
 * nueva sabe qué estados ya atendió la anterior. Cada caso simula la composición nueva preguntando por el mismo estado.
 * Paridad con iOS: `onChange` solo reacciona a cambios, así que allí no hace falta.
 */
class EventosDeCuentaTest {
    private val sesion = Sesion("g-1", "g@gmail.com", nombre = "Gabriel")

    @Test fun `H-5a al rotar en el aviso el arranque y la sesion iniciada no se vuelven a atender`() {
        val eventos = EventosDeCuenta()
        val sesionIniciada = EstadoDeRegistro.SesionIniciada(sesion)
        // Primera composición: arranque y «sesión iniciada» llevan al aviso (que se reinicia una vez).
        assertTrue(eventos.pendiente(EventosDeCuenta.ARRANQUE, Unit)); eventos.atendido(EventosDeCuenta.ARRANQUE, Unit)
        assertTrue(eventos.pendiente(EventosDeCuenta.REGISTRO, sesionIniciada)); eventos.atendido(EventosDeCuenta.REGISTRO, sesionIniciada)
        assertTrue(eventos.pendiente(EventosDeCuenta.AVISO, EstadoDelAviso.ErrorAlCerrarSesion))
        eventos.atendido(EventosDeCuenta.AVISO, EstadoDelAviso.ErrorAlCerrarSesion)

        // Rotación: composición nueva, mismos estados. Nada se vuelve a atender: las casillas y el error se quedan.
        assertFalse("el arranque no vuelve a pedir el aviso", eventos.pendiente(EventosDeCuenta.ARRANQUE, Unit))
        assertFalse("la sesion iniciada no reinicia el aviso", eventos.pendiente(EventosDeCuenta.REGISTRO, sesionIniciada))
        assertFalse(eventos.pendiente(EventosDeCuenta.AVISO, EstadoDelAviso.ErrorAlCerrarSesion))
    }

    @Test fun `H-5b al rotar en Proximamente no se regresa a Sesion iniciada y la sesion se conserva`() {
        val eventos = EventosDeCuenta()
        eventos.atendido(EventosDeCuenta.AVISO, EstadoDelAviso.Aceptado)
        eventos.sesionActivada = sesion
        eventos.atendido(EventosDeCuenta.ACCESO, EstadoDeAcceso.ConSesion(sesion))

        assertFalse("Aceptado ya llevo a Sesion iniciada", eventos.pendiente(EventosDeCuenta.AVISO, EstadoDelAviso.Aceptado))
        assertFalse(eventos.pendiente(EventosDeCuenta.ACCESO, EstadoDeAcceso.ConSesion(sesion)))
        assertEquals(sesion, eventos.sesionActivada)
    }

    @Test fun `H-5 un estado nuevo si se atiende y uno interrumpido por la rotacion se vuelve a atender`() {
        val eventos = EventosDeCuenta()
        eventos.atendido(EventosDeCuenta.AVISO, EstadoDelAviso.Aceptado)

        assertTrue(eventos.pendiente(EventosDeCuenta.AVISO, EstadoDelAviso.Rechazado))
        eventos.atendido(EventosDeCuenta.AVISO, EstadoDelAviso.Pendiente)
        assertTrue("tras otro estado, Aceptado vuelve a contar", eventos.pendiente(EventosDeCuenta.AVISO, EstadoDelAviso.Aceptado))
        // Sin marcar (la rotación canceló la atención a media consulta): la composición nueva lo atiende.
        assertTrue(eventos.pendiente(EventosDeCuenta.REGISTRO, EstadoDeRegistro.SesionIniciada(sesion)))
    }
}
