package mx.rugbyapp.domain.cuentas

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * C-02 · CP-165: inicio de sesión con correo y contraseña (D-5) y la regla de las revocaciones pendientes al iniciar
 * (P-4, ADR 0010). Reglas de domain-model.md §1. Mismos casos que
 * ios/Packages/Domain/Tests/DomainTests/IniciarSesionConCorreoUseCaseTests.swift.
 */
class IniciarSesionConCorreoUseCaseTest {
    private val bitacora = Bitacora()
    private val sesiones = RepositorioFalso(bitacora)
    private var pendientes = RepositorioDeRevocacionesPendientesFalso(bitacora)
    private var consentimiento = RepositorioDeConsentimientoFalso(setOf(AvisoDePrivacidad.VERSION_VIGENTE), bitacora)

    private fun reintentar() = ReintentarRevocacionesPendientesUseCase(pendientes, RelojFalso(pendientes.ahora))
    private fun casoDeUso() = IniciarSesionConCorreoUseCase(sesiones, pendientes, reintentar(), consentimiento)

    @Test fun `CP-165a correo y contrasena validos llegan normalizados y devuelve la sesion`() {
        val sesion = correr { casoDeUso().ejecutar(CredencialesDeCorreo("  Daniela@Ejemplo.MX ", " Clave Larga 1 ")) }

        assertEquals("daniela@ejemplo.mx", sesiones.correoRecibido)
        assertEquals(" Clave Larga 1 ", sesiones.contrasenaRecibida)
        assertEquals(Sesion("u-1", "a@b.mx"), sesion)
    }

    @Test fun `CP-165b correo invalido o contrasena vacia no llaman al repositorio`() {
        assertThrows(ErrorDeAutenticacion.CorreoInvalido::class.java) {
            correr { casoDeUso().ejecutar(CredencialesDeCorreo("daniela@ejemplo", "clave-larga-1")) }
        }
        assertThrows(ErrorDeAutenticacion.CredencialRechazada::class.java) {
            correr { casoDeUso().ejecutar(CredencialesDeCorreo("daniela@ejemplo.mx", "")) }
        }
        assertFalse(bitacora.llamadas.contains("iniciarSesionConCorreo"))
    }

    @Test fun `CP-165c los errores del repositorio se propagan sin transformarse`() {
        for (error in listOf(
            ErrorDeAutenticacion.CredencialRechazada, ErrorDeAutenticacion.CorreoSinVerificar,
            ErrorDeAutenticacion.DemasiadosIntentos, ErrorDeAutenticacion.SinConexion,
        )) {
            sesiones.resultadoDeInicio = Result.failure(error)
            assertThrows(error::class.java) { correr { casoDeUso().ejecutar(CredencialesDeCorreo("daniela@ejemplo.mx", "x")) } }
        }
    }

    @Test fun `CP-165d antes de iniciar reintenta las pendientes y si falla el inicio sigue`() {
        pendientes = RepositorioDeRevocacionesPendientesFalso(
            bitacora, guardadas = listOf(RevocacionPendiente("vieja", "u-9", null, 999_000)),
        ).apply { errorAlRevocar = ErrorDeAutenticacion.SinConexion }

        correr { casoDeUso().ejecutar(CredencialesDeCorreo("daniela@ejemplo.mx", "clave")) }

        assertEquals(
            listOf("revocar(vieja)", "iniciarSesionConCorreo"),
            bitacora.llamadas.filter { it in setOf("revocar(vieja)", "iniciarSesionConCorreo") },
        )
        assertEquals(listOf("vieja"), pendientes.guardadas.map { it.id })
    }

    /**
     * R-1 (CA-7, P-4): el reintento previo falló, pero el inicio funcionó. El aviso de la pendiente de la misma cuenta se
     * revoca en línea con la sesión nueva ANTES de `quitarAviso`; la pendiente conserva solo la revocación de la sesión
     * vieja y las de otra cuenta no cambian. Después la App consulta el aviso y lo vuelve a pedir.
     */
    @Test fun `CP-165e tras iniciar el aviso pendiente se revoca con la sesion nueva antes de quitarlo y las de otra no cambian`() {
        val deX = RevocacionPendiente("x", "u-1", "v0-borrador", 999_000)
        val deOtra = RevocacionPendiente("o", "u-2", "v0-borrador", 999_000)
        pendientes = RepositorioDeRevocacionesPendientesFalso(bitacora, guardadas = listOf(deX, deOtra))
            .apply { errorAlRevocar = ErrorDeAutenticacion.SinConexion }

        correr { casoDeUso().ejecutar(CredencialesDeCorreo("a@b.mx", "clave")) }

        assertEquals("el No acepto no se pierde", listOf("v0-borrador"), consentimiento.revocaciones)
        assertFalse("v0-borrador" in consentimiento.aceptadas)
        assertEquals(
            listOf("iniciarSesionConCorreo", "revocarAviso", "quitarAviso(u-1)"),
            bitacora.llamadas.filter { it in setOf("iniciarSesionConCorreo", "revocarAviso", "quitarAviso(u-1)") },
        )
        assertEquals(
            "la de u-1 conserva la revocacion de la sesion vieja, sin el aviso",
            listOf(RevocacionPendiente("x", "u-1", null, 999_000), deOtra),
            pendientes.guardadas,
        )
    }

    @Test fun `CP-165e con Google tambien revoca el aviso con la sesion nueva y lo quita de la pendiente`() {
        pendientes = RepositorioDeRevocacionesPendientesFalso(bitacora, guardadas = listOf(RevocacionPendiente("x", "u-1", "v0-borrador", 999_000)))
            .apply { errorAlRevocar = ErrorDeAutenticacion.SinConexion }
        val google = IniciarSesionUseCase(
            GeneradorFalso("crudo", bitacora), HashFalso(bitacora),
            ObtenedorFalso(Result.success(CredencialNativa(ProveedorDeIdentidad.GOOGLE, "t", null)), bitacora),
            sesiones, pendientes, reintentar(), consentimiento,
        )

        correr { google.ejecutar(ProveedorDeIdentidad.GOOGLE) }

        assertEquals(listOf<String?>(null), pendientes.guardadas.map { it.versionDelAvisoPorRevocar })
        assertEquals(listOf("v0-borrador"), consentimiento.revocaciones)
        val orden = bitacora.llamadas.filter { it == "revocar(x)" || it.startsWith("obtener") || it == "revocarAviso" || it == "quitarAviso(u-1)" }
        assertEquals("reintenta antes de abrir Google", "revocar(x)", orden.first())
        assertEquals(listOf("revocarAviso", "quitarAviso(u-1)"), orden.takeLast(2))
    }

    /**
     * R-1: si la revocación en línea falla y el aviso sigue aceptado, la pendiente conserva el aviso (no se pierde el
     * «No acepto»). Si falla pero el aviso ya no está aceptado (la respuesta se perdió), se quita igual.
     */
    @Test fun `CP-165g si la revocacion en linea falla la pendiente conserva el aviso salvo que ya no este aceptado`() {
        val deX = RevocacionPendiente("x", "u-1", "v0-borrador", 999_000)
        pendientes = RepositorioDeRevocacionesPendientesFalso(bitacora, guardadas = listOf(deX))
            .apply { errorAlRevocar = ErrorDeAutenticacion.SinConexion }
        consentimiento.errorAlRevocar = ErrorDeConsentimiento.SinConexion

        val sesion = correr { casoDeUso().ejecutar(CredencialesDeCorreo("a@b.mx", "clave")) }

        assertEquals("el inicio de sesion no falla por el aviso", "u-1", sesion.usuarioId)
        assertEquals("sigue aceptado: la pendiente conserva el aviso", listOf(deX), pendientes.guardadas)
        assertFalse(bitacora.llamadas.contains("quitarAviso(u-1)"))

        consentimiento = RepositorioDeConsentimientoFalso(emptySet(), bitacora).apply { errorAlRevocar = ErrorDeConsentimiento.SinConexion }
        correr { casoDeUso().ejecutar(CredencialesDeCorreo("a@b.mx", "clave")) }

        assertEquals("ya no esta aceptado: se quita", listOf<String?>(null), pendientes.guardadas.map { it.versionDelAvisoPorRevocar })
    }

    /**
     * R-1, P-4: sin pendientes con aviso de esa cuenta no se revoca nada en línea (ni se consulta): una aceptación de la
     * sesión nueva nunca se toca, y tampoco el aviso de otra cuenta.
     */
    @Test fun `CP-165h sin pendientes con aviso de esa cuenta no se revoca ningun aviso`() {
        pendientes = RepositorioDeRevocacionesPendientesFalso(
            bitacora,
            guardadas = listOf(RevocacionPendiente("x", "u-1", null, 999_000), RevocacionPendiente("o", "u-2", "v0-borrador", 999_000)),
        ).apply { errorAlRevocar = ErrorDeAutenticacion.SinConexion }

        correr { casoDeUso().ejecutar(CredencialesDeCorreo("a@b.mx", "clave")) }

        assertEquals(emptyList<String>(), consentimiento.revocaciones)
        assertEquals(emptyList<String>(), consentimiento.versionesConsultadas)
        assertTrue("v0-borrador" in consentimiento.aceptadas)
    }

    @Test fun `CP-165f la descripcion de las credenciales no contiene la contrasena`() {
        val credenciales = CredencialesDeCorreo("daniela@ejemplo.mx", "secreta-123")

        assertFalse(credenciales.toString().contains("secreta-123"))
        assertFalse("$credenciales".contains("secreta-123"))
    }
}
