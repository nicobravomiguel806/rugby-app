package mx.rugbyapp.domain.cuentas

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * C-01 · CP-114b–d y f (aviso de privacidad y finalidades secundarias), CP-164a–d (rechazo del aviso, CA-9) y
 * CP-164e–g (H-6: la carrera del enlace al arrancar y la revocación del aviso como registro nuevo).
 * Reglas de domain-model.md §1. Mismos casos que ios/Packages/Domain/Tests/DomainTests/AvisoDePrivacidadUseCaseTests.swift.
 */
class AvisoDePrivacidadUseCaseTest {
    private val sesion = Sesion("u-1", "a@b.mx")

    @Test fun `CP-114b aceptar envia la version vigente y las finalidades marcadas`() {
        val repositorio = RepositorioDeConsentimientoFalso()
        val caso = AceptarAvisoDePrivacidadUseCase(repositorio)

        correr { caso.ejecutar(finalidades = setOf(FinalidadSecundaria.NOTIFICACIONES)) }
        correr { caso.ejecutar(finalidades = emptySet()) }

        assertEquals("v0-borrador", AvisoDePrivacidad.VERSION_VIGENTE)
        assertEquals(listOf("v0-borrador", "v0-borrador"), repositorio.llamadasAAceptar.map { it.first })
        assertEquals(listOf(setOf(FinalidadSecundaria.NOTIFICACIONES), emptySet()), repositorio.llamadasAAceptar.map { it.second })
    }

    @Test fun `CP-114c consultar pregunta siempre por la version vigente`() {
        val repositorio = RepositorioDeConsentimientoFalso(aceptadas = setOf("v0-borrador"))

        val aceptado = correr { ConsultarAvisoAceptadoUseCase(repositorio).ejecutar() }

        assertTrue(aceptado)
        assertEquals(listOf("v0-borrador"), repositorio.versionesConsultadas)
    }

    @Test fun `CP-114d version desactualizada se propaga sin transformarse`() {
        val repositorio = RepositorioDeConsentimientoFalso().apply { errorAlAceptar = ErrorDeConsentimiento.VersionDesactualizada }

        assertThrows(ErrorDeConsentimiento.VersionDesactualizada::class.java) {
            correr { AceptarAvisoDePrivacidadUseCase(repositorio).ejecutar(finalidades = emptySet()) }
        }
    }

    @Test fun `CP-114f las finalidades son las tres del aviso en orden y cada una se decide aparte`() {
        assertEquals(
            listOf(FinalidadSecundaria.NOTIFICACIONES, FinalidadSecundaria.COMUNICACIONES, FinalidadSecundaria.ESTADISTICAS),
            FinalidadSecundaria.entries.toList(),
        )
        assertEquals(listOf("notificaciones", "comunicaciones", "estadisticas"), FinalidadSecundaria.entries.map { it.valorCrudo })

        val repositorio = RepositorioDeConsentimientoFalso()
        correr {
            AceptarAvisoDePrivacidadUseCase(repositorio)
                .ejecutar(finalidades = setOf(FinalidadSecundaria.NOTIFICACIONES, FinalidadSecundaria.ESTADISTICAS))
        }

        val enviadas = repositorio.llamadasAAceptar.first().second
        assertEquals(setOf(FinalidadSecundaria.NOTIFICACIONES, FinalidadSecundaria.ESTADISTICAS), enviadas)
        assertFalse(FinalidadSecundaria.COMUNICACIONES in enviadas)
    }

    @Test fun `CP-164a primer inicio con Google rechazado cierra la sesion sin guardar nada`() {
        val bitacora = Bitacora()
        val sesiones = RepositorioFalso(bitacora, sesion)
        val consentimientos = RepositorioDeConsentimientoFalso()

        assertFalse(correr { ConsultarAvisoAceptadoUseCase(consentimientos).ejecutar() })

        correr { RechazarAvisoDePrivacidadUseCase(consentimientos, CerrarSesionUseCase(sesiones)).ejecutar() }

        assertNull(correr { sesiones.sesionActual() })
        assertEquals(1, bitacora.llamadas.count { it == "borrarSesionLocal" })
        assertEquals(0, consentimientos.llamadasAAceptar.size)
        assertEquals("sin consentimiento previo no se guarda nada, tampoco una revocacion", emptyList<String>(), consentimientos.revocaciones)
    }

    @Test fun `CP-164b si la revocacion falla el rechazo termina sin error y la sesion local queda borrada`() {
        val sesiones = RepositorioFalso(Bitacora(), sesion).apply { errorAlRevocar = ErrorDeAutenticacion.SinConexion }

        correr { RechazarAvisoDePrivacidadUseCase(RepositorioDeConsentimientoFalso(), CerrarSesionUseCase(sesiones)).ejecutar() }

        assertNull(correr { sesiones.sesionActual() })
    }

    @Test fun `CP-164c si borrar la sesion local falla el error se propaga sin transformarse`() {
        val sesiones = RepositorioFalso(Bitacora(), sesion).apply { errorAlBorrar = ErrorDeAutenticacion.Desconocido }

        assertThrows(ErrorDeAutenticacion.Desconocido::class.java) {
            correr { RechazarAvisoDePrivacidadUseCase(RepositorioDeConsentimientoFalso(), CerrarSesionUseCase(sesiones)).ejecutar() }
        }
        assertEquals(sesion, correr { sesiones.sesionActual() })
    }

    @Test fun `CP-164d app cerrada sin decidir el aviso se vuelve a pedir en el siguiente arranque`() {
        val sesiones = RepositorioFalso(Bitacora(), sesion)
        val consentimientos = RepositorioDeConsentimientoFalso()

        val primerArranque = correr { ConsultarAvisoAceptadoUseCase(consentimientos).ejecutar() }
        // La app se cierra sin aceptar ni rechazar: no se llama a nada más.
        val sesionGuardada = correr { ObtenerSesionActualUseCase(sesiones).ejecutar() }
        val segundoArranque = correr { ConsultarAvisoAceptadoUseCase(consentimientos).ejecutar() }

        assertFalse(primerArranque)
        assertEquals(sesion, sesionGuardada)
        assertFalse(segundoArranque)
        assertEquals(0, consentimientos.llamadasAAceptar.size)
    }

    // H-6 · La carrera: en un arranque en frío desde el enlace del correo, la consulta del arranque cae entre el canje
    // del enlace y el registro del aviso. Si llegó un enlace (antes o durante la consulta), el arranque no pide el aviso:
    // lo consulta el flujo del enlace después de registrar lo marcado en el formulario.
    @Test fun `CP-164e si llega un enlace mientras se consulta el aviso al arrancar no se pide`() {
        val sesiones = RepositorioFalso(Bitacora(), sesion)
        val consentimientos = RepositorioDeConsentimientoFalso()
        var enlace = false
        consentimientos.alConsultar = { enlace = true } // el canje ya dio sesión; el aviso aún no se registra
        val caso = HayQuePedirElAvisoAlArrancarUseCase(ObtenerSesionActualUseCase(sesiones), ConsultarAvisoAceptadoUseCase(consentimientos))

        val duranteLaConsulta = correr { caso.ejecutar(llegoUnEnlace = { enlace }) }
        val consultasAntes = consentimientos.versionesConsultadas.size
        val conElEnlaceYaRecibido = correr { caso.ejecutar(llegoUnEnlace = { true }) }

        assertFalse("el aviso no se pide si llego un enlace durante la consulta", duranteLaConsulta)
        assertFalse(conElEnlaceYaRecibido)
        assertEquals("con el enlace ya recibido ni siquiera consulta", consultasAntes, consentimientos.versionesConsultadas.size)
        assertEquals(0, consentimientos.llamadasAAceptar.size)
    }

    @Test fun `CP-164e sin enlace con sesion y sin aviso se pide y sin red no se bloquea`() {
        val consentimientos = RepositorioDeConsentimientoFalso()
        val caso = HayQuePedirElAvisoAlArrancarUseCase(
            ObtenerSesionActualUseCase(RepositorioFalso(Bitacora(), sesion)), ConsultarAvisoAceptadoUseCase(consentimientos),
        )

        val sinAviso = correr { caso.ejecutar(llegoUnEnlace = { false }) }
        consentimientos.errorAlConsultar = ErrorDeConsentimiento.SinConexion
        val sinRed = correr { caso.ejecutar(llegoUnEnlace = { false }) }
        val sinSesion = correr {
            HayQuePedirElAvisoAlArrancarUseCase(
                ObtenerSesionActualUseCase(RepositorioFalso(Bitacora())), ConsultarAvisoAceptadoUseCase(RepositorioDeConsentimientoFalso()),
            ).ejecutar(llegoUnEnlace = { false })
        }

        assertTrue(sinAviso)
        assertFalse(sinRed)
        assertFalse(sinSesion)
    }

    // H-6 · La revocación: si ya había un consentimiento guardado (la carrera) y pulsa «No acepto», se registra la
    // revocación como registro nuevo antes de cerrar la sesión. Después el aviso vigente ya no está aceptado y se puede
    // aceptar otra vez.
    @Test fun `CP-164f con consentimiento previo no acepto registra la revocacion antes de cerrar la sesion`() {
        val bitacora = Bitacora()
        val sesiones = RepositorioFalso(bitacora, sesion)
        val consentimientos = RepositorioDeConsentimientoFalso(aceptadas = setOf("v0-borrador"), bitacora = bitacora)

        correr { RechazarAvisoDePrivacidadUseCase(consentimientos, CerrarSesionUseCase(sesiones)).ejecutar() }

        assertEquals(listOf("v0-borrador"), consentimientos.revocaciones)
        assertEquals(
            "la revocacion va antes de cerrar la sesion",
            listOf("revocarAviso", "borrarSesionLocal"),
            bitacora.llamadas.filter { it in setOf("revocarAviso", "borrarSesionLocal") },
        )
        assertNull(correr { sesiones.sesionActual() })
        assertEquals(0, consentimientos.llamadasAAceptar.size)
        assertFalse("tras la revocacion el aviso se vuelve a pedir", correr { ConsultarAvisoAceptadoUseCase(consentimientos).ejecutar() })
        correr { AceptarAvisoDePrivacidadUseCase(consentimientos).ejecutar(finalidades = emptySet()) }
        assertTrue("se puede aceptar otra vez", correr { ConsultarAvisoAceptadoUseCase(consentimientos).ejecutar() })
    }

    // H-6 · Si la revocación no se puede registrar, la sesión del dispositivo se cierra de todas formas (no deja a la
    // persona dentro) y el error de consentimiento se propaga sin transformarse, para que la UI salga del aviso.
    @Test fun `CP-164g si la revocacion falla la sesion se cierra igual y el error se propaga`() {
        val sesiones = RepositorioFalso(Bitacora(), sesion)
        val consentimientos = RepositorioDeConsentimientoFalso(aceptadas = setOf("v0-borrador")).apply {
            errorAlRevocar = ErrorDeConsentimiento.SinConexion
        }

        assertThrows(ErrorDeConsentimiento.SinConexion::class.java) {
            correr { RechazarAvisoDePrivacidadUseCase(consentimientos, CerrarSesionUseCase(sesiones)).ejecutar() }
        }
        assertNull(correr { sesiones.sesionActual() })
    }
}
