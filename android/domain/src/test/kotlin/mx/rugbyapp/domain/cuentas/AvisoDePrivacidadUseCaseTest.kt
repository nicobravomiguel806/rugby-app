package mx.rugbyapp.domain.cuentas

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * C-01 · CP-114b–d y f (aviso de privacidad y finalidades secundarias) y CP-164a–d (rechazo del aviso, CA-9).
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

        correr { RechazarAvisoDePrivacidadUseCase(CerrarSesionUseCase(sesiones)).ejecutar() }

        assertNull(correr { sesiones.sesionActual() })
        assertEquals(1, bitacora.llamadas.count { it == "borrarSesionLocal" })
        assertEquals(0, consentimientos.llamadasAAceptar.size)
    }

    @Test fun `CP-164b si la revocacion falla el rechazo termina sin error y la sesion local queda borrada`() {
        val sesiones = RepositorioFalso(Bitacora(), sesion).apply { errorAlRevocar = ErrorDeAutenticacion.SinConexion }

        correr { RechazarAvisoDePrivacidadUseCase(CerrarSesionUseCase(sesiones)).ejecutar() }

        assertNull(correr { sesiones.sesionActual() })
    }

    @Test fun `CP-164c si borrar la sesion local falla el error se propaga sin transformarse`() {
        val sesiones = RepositorioFalso(Bitacora(), sesion).apply { errorAlBorrar = ErrorDeAutenticacion.Desconocido }

        assertThrows(ErrorDeAutenticacion.Desconocido::class.java) {
            correr { RechazarAvisoDePrivacidadUseCase(CerrarSesionUseCase(sesiones)).ejecutar() }
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
}
