package mx.rugbyapp.domain.cuentas

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
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

    private fun reintentar() = ReintentarRevocacionesPendientesUseCase(pendientes, RelojFalso(pendientes.ahora))
    private fun casoDeUso() = IniciarSesionConCorreoUseCase(sesiones, pendientes, reintentar())

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

    @Test fun `CP-165e tras iniciar la pendiente de la misma cuenta pierde el aviso y las de otra no cambian`() {
        val deX = RevocacionPendiente("x", "u-1", "v0-borrador", 999_000)
        val deOtra = RevocacionPendiente("o", "u-2", "v0-borrador", 999_000)
        pendientes = RepositorioDeRevocacionesPendientesFalso(bitacora, guardadas = listOf(deX, deOtra))
            .apply { errorAlRevocar = ErrorDeAutenticacion.SinConexion }

        correr { casoDeUso().ejecutar(CredencialesDeCorreo("a@b.mx", "clave")) }

        assertEquals(
            "la de u-1 conserva la revocacion de la sesion vieja, sin el aviso",
            listOf(RevocacionPendiente("x", "u-1", null, 999_000), deOtra),
            pendientes.guardadas,
        )
    }

    @Test fun `CP-165e con Google tambien quita el aviso de la pendiente de la misma cuenta`() {
        pendientes = RepositorioDeRevocacionesPendientesFalso(bitacora, guardadas = listOf(RevocacionPendiente("x", "u-1", "v0-borrador", 999_000)))
            .apply { errorAlRevocar = ErrorDeAutenticacion.SinConexion }
        val google = IniciarSesionUseCase(
            GeneradorFalso("crudo", bitacora), HashFalso(bitacora),
            ObtenedorFalso(Result.success(CredencialNativa(ProveedorDeIdentidad.GOOGLE, "t", null)), bitacora),
            sesiones, pendientes, reintentar(),
        )

        correr { google.ejecutar(ProveedorDeIdentidad.GOOGLE) }

        assertEquals(listOf<String?>(null), pendientes.guardadas.map { it.versionDelAvisoPorRevocar })
        assertEquals(
            "reintenta antes de abrir Google",
            "revocar(x)",
            bitacora.llamadas.first { it == "revocar(x)" || it.startsWith("obtener") },
        )
    }

    @Test fun `CP-165f la descripcion de las credenciales no contiene la contrasena`() {
        val credenciales = CredencialesDeCorreo("daniela@ejemplo.mx", "secreta-123")

        assertFalse(credenciales.toString().contains("secreta-123"))
        assertFalse("$credenciales".contains("secreta-123"))
    }
}
