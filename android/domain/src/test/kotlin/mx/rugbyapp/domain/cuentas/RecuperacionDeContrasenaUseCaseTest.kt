package mx.rugbyapp.domain.cuentas

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * C-02 · CP-166: recuperación de la contraseña por correo (CA-2, D-7). Reglas de domain-model.md §1.
 * Mismos casos que ios/Packages/Domain/Tests/DomainTests/RecuperacionDeContrasenaUseCaseTests.swift.
 */
class RecuperacionDeContrasenaUseCaseTest {
    @Test fun `CP-166a pedir normaliza el correo y devuelve enlace enviado`() {
        val repositorio = RepositorioDeRecuperacionFalso()

        val resultado = correr { PedirRecuperacionDeContrasenaUseCase(repositorio).ejecutar(correo = "  Daniela@Ejemplo.MX ") }

        assertEquals(ResultadoDeRecuperacion.EnlaceEnviado("daniela@ejemplo.mx"), resultado)
        assertEquals(listOf("daniela@ejemplo.mx"), repositorio.enviados)
    }

    @Test fun `CP-166a correo invalido no llama al repositorio`() {
        val repositorio = RepositorioDeRecuperacionFalso()

        assertThrows(ErrorDeRecuperacion.CorreoInvalido::class.java) {
            correr { PedirRecuperacionDeContrasenaUseCase(repositorio).ejecutar(correo = "daniela@") }
        }
        assertEquals(emptyList<String>(), repositorio.enviados)
    }

    @Test fun `CP-166b con cuenta y sin cuenta el resultado es el mismo`() {
        val conCuenta = RepositorioDeRecuperacionFalso(conocidos = setOf("daniela@ejemplo.mx"))
        val sinCuenta = RepositorioDeRecuperacionFalso(conocidos = emptySet())

        val uno = correr { PedirRecuperacionDeContrasenaUseCase(conCuenta).ejecutar(correo = "daniela@ejemplo.mx") }
        val otro = correr { PedirRecuperacionDeContrasenaUseCase(sinCuenta).ejecutar(correo = "daniela@ejemplo.mx") }

        assertEquals(uno, otro)
        assertEquals(1, conCuenta.enviadosAConocidos.size)
        assertEquals(0, sinCuenta.enviadosAConocidos.size)
    }

    @Test fun `CP-166c restablecer exige diez caracteres y cambia cierra las otras y termina`() {
        val bitacora = Bitacora()
        val repositorio = RepositorioDeRecuperacionFalso(bitacora, enCurso = true)
        val caso = RestablecerContrasenaUseCase(repositorio)

        assertThrows(ErrorDeRecuperacion.ContrasenaCorta::class.java) { correr { caso.ejecutar(nueva = "123456789") } }
        assertEquals(emptyList<String>(), bitacora.llamadas)

        correr { caso.ejecutar(nueva = "aaaaaaaaaa") }

        assertEquals(listOf("cambiarContrasena", "cerrarOtrasSesiones", "terminarRecuperacion"), bitacora.llamadas)
        assertEquals(listOf("aaaaaaaaaa"), repositorio.contrasenasRecibidas)
        assertFalse(correr { repositorio.recuperacionEnCurso() })
    }

    @Test fun `CP-166d confirmar un enlace invalido no deja la recuperacion en curso`() {
        val repositorio = RepositorioDeRecuperacionFalso().apply { errorAlConfirmar = ErrorDeRecuperacion.EnlaceInvalido }

        assertThrows(ErrorDeRecuperacion.EnlaceInvalido::class.java) {
            correr { ConfirmarRecuperacionDeContrasenaUseCase(repositorio).ejecutar(enlace = "rugbyapp://recuperar-contrasena?error=otp_expired") }
        }
        assertFalse(correr { repositorio.recuperacionEnCurso() })
    }

    @Test fun `CP-166d confirmar un enlace valido devuelve la sesion y deja la recuperacion en curso`() {
        val repositorio = RepositorioDeRecuperacionFalso()

        val sesion = correr { ConfirmarRecuperacionDeContrasenaUseCase(repositorio).ejecutar(enlace = "rugbyapp://recuperar-contrasena?code=abc") }

        assertEquals(repositorio.sesionAlConfirmar, sesion)
        assertEquals(listOf("rugbyapp://recuperar-contrasena?code=abc"), repositorio.enlacesRecibidos)
        assertTrue(correr { repositorio.recuperacionEnCurso() })
    }

    @Test fun `CP-166e abandonar con recuperacion en curso cierra la sesion y quita la marca`() {
        val bitacora = Bitacora()
        val sesiones = RepositorioFalso(bitacora, Sesion("u-1", "a@b.mx"))
        val pendientes = RepositorioDeRevocacionesPendientesFalso(bitacora)
        val repositorio = RepositorioDeRecuperacionFalso(bitacora, enCurso = true)

        correr { CerrarRecuperacionAbandonadaUseCase(repositorio, cerrarSesion(sesiones, pendientes)).ejecutar() }

        assertNull(correr { sesiones.sesionActual() })
        assertFalse(correr { repositorio.recuperacionEnCurso() })
        assertEquals(
            "pasa por CerrarSesionUseCase y despues quita la marca",
            listOf("borrarSesionLocal", "terminarRecuperacion"),
            bitacora.llamadas.filter { it in setOf("borrarSesionLocal", "terminarRecuperacion") },
        )
    }

    @Test fun `CP-166e sin recuperacion en curso no hace nada`() {
        val bitacora = Bitacora()
        val sesion = Sesion("u-1", "a@b.mx")
        val sesiones = RepositorioFalso(bitacora, sesion)
        val repositorio = RepositorioDeRecuperacionFalso(bitacora, enCurso = false)

        correr { CerrarRecuperacionAbandonadaUseCase(repositorio, cerrarSesion(sesiones)).ejecutar() }

        assertEquals(sesion, correr { sesiones.sesionActual() })
        assertFalse(bitacora.llamadas.contains("borrarSesionLocal"))
        assertFalse(bitacora.llamadas.contains("terminarRecuperacion"))
    }

    @Test fun `CP-166f los errores del repositorio se propagan sin transformarse`() {
        for (error in listOf(ErrorDeRecuperacion.DemasiadosIntentos, ErrorDeRecuperacion.SinConexion)) {
            val repositorio = RepositorioDeRecuperacionFalso().apply { errorAlEnviar = error }
            assertThrows(error::class.java) {
                correr { PedirRecuperacionDeContrasenaUseCase(repositorio).ejecutar(correo = "daniela@ejemplo.mx") }
            }
        }
    }

    @Test fun `CP-166f si cambiar la contrasena falla no se cierran las otras y sigue en curso`() {
        val bitacora = Bitacora()
        val repositorio = RepositorioDeRecuperacionFalso(bitacora, enCurso = true).apply { errorAlCambiar = ErrorDeRecuperacion.SinConexion }

        assertThrows(ErrorDeRecuperacion.SinConexion::class.java) {
            correr { RestablecerContrasenaUseCase(repositorio).ejecutar(nueva = "clave-larga-1") }
        }
        assertEquals(listOf("cambiarContrasena"), bitacora.llamadas)
        assertTrue(correr { repositorio.recuperacionEnCurso() })
    }
}
