package mx.rugbyapp.domain.cuentas

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

/**
 * C-01 · CP-160 (validación del registro) y CP-114a/e (aviso en el formulario). Reglas de domain-model.md §1.
 * Mismos casos que ios/Packages/Domain/Tests/DomainTests/RegistrarUsuarioUseCaseTests.swift.
 */
class RegistrarUsuarioUseCaseTest {
    private fun datos(
        nombre: String = "Daniela Pérez",
        correo: String = "daniela@ejemplo.mx",
        contrasena: String = "contrasena-larga",
        aviso: Boolean = true,
    ) = DatosDeRegistro(nombreCompleto = nombre, correo = correo, contrasena = contrasena, aceptoAvisoDePrivacidad = aviso)

    private fun caso(repositorio: RepositorioDeRegistroFalso) = RegistrarUsuarioUseCase(ValidadorDeRegistro(), repositorio)

    private fun erroresAlRegistrar(d: DatosDeRegistro, repositorio: RepositorioDeRegistroFalso): List<ErrorDeRegistro> =
        try {
            correr { caso(repositorio).ejecutar(d) }
            fail("Se esperaban errores de validación")
            emptyList()
        } catch (e: ErroresDeValidacion) {
            e.errores
        }

    @Test fun `CP-160a datos validos llaman al repositorio una vez y devuelven enlace enviado`() {
        val repositorio = RepositorioDeRegistroFalso()

        val resultado = correr { caso(repositorio).ejecutar(datos(correo = "Daniela@Ejemplo.mx")) }

        assertEquals(ResultadoDeRegistro.EnlaceEnviado("daniela@ejemplo.mx"), resultado)
        assertEquals(1, repositorio.registrados.size)
    }

    @Test fun `CP-160b nombre vacio o solo espacios es nombre invalido sin llamar al repositorio`() {
        for (nombre in listOf("", "    ")) {
            val repositorio = RepositorioDeRegistroFalso()
            assertEquals("nombre «$nombre»", listOf(ErrorDeRegistro.NombreInvalido), erroresAlRegistrar(datos(nombre = nombre), repositorio))
            assertTrue(repositorio.registrados.isEmpty())
        }
    }

    @Test fun `CP-160c limites del nombre tras quitar espacios`() {
        val validador = ValidadorDeRegistro()
        assertEquals(listOf(ErrorDeRegistro.NombreInvalido), validador.validar(datos(nombre = "  A  ")))
        assertEquals(emptyList<ErrorDeRegistro>(), validador.validar(datos(nombre = " Al ")))
        assertEquals(emptyList<ErrorDeRegistro>(), validador.validar(datos(nombre = "a".repeat(120))))
        assertEquals(emptyList<ErrorDeRegistro>(), validador.validar(datos(nombre = " " + "a".repeat(120) + " ")))
        assertEquals(listOf(ErrorDeRegistro.NombreInvalido), validador.validar(datos(nombre = "a".repeat(121))))
    }

    @Test fun `CP-160d correo sin arroba o sin dominio es correo invalido`() {
        val validador = ValidadorDeRegistro()
        for (correo in listOf("danielaejemplo.mx", "daniela@", "daniela@ejemplo", "@ejemplo.mx", "daniela@.mx", "dani ela@ejemplo.mx", "")) {
            assertEquals("correo «$correo»", listOf(ErrorDeRegistro.CorreoInvalido), validador.validar(datos(correo = correo)))
        }
        assertEquals(emptyList<ErrorDeRegistro>(), validador.validar(datos(correo = "  daniela@ejemplo.mx  ")))
    }

    @Test fun `CP-160e contrasena de 9 es corta y de 10 es valida sin reglas de composicion`() {
        val validador = ValidadorDeRegistro()
        assertEquals(listOf(ErrorDeRegistro.ContrasenaCorta), validador.validar(datos(contrasena = "123456789")))
        assertEquals(emptyList<ErrorDeRegistro>(), validador.validar(datos(contrasena = "1234567890")))
        assertEquals(emptyList<ErrorDeRegistro>(), validador.validar(datos(contrasena = "aaaaaaaaaa")))
    }

    @Test fun `CP-160f varios errores se devuelven todos en orden fijo`() {
        val repositorio = RepositorioDeRegistroFalso()

        val errores = erroresAlRegistrar(datos(nombre = " ", correo = "x", contrasena = "corta", aviso = false), repositorio)

        assertEquals(
            listOf(ErrorDeRegistro.NombreInvalido, ErrorDeRegistro.CorreoInvalido, ErrorDeRegistro.ContrasenaCorta, ErrorDeRegistro.AvisoNoAceptado),
            errores,
        )
        assertTrue(repositorio.registrados.isEmpty())
    }

    @Test fun `CP-160g el repositorio recibe los datos normalizados y la contrasena sin cambios`() {
        val repositorio = RepositorioDeRegistroFalso()

        correr { caso(repositorio).ejecutar(datos(nombre = "  Daniela Pérez ", correo = "  Daniela@Ejemplo.MX ", contrasena = "  Clave Con Espacios  ")) }

        val recibido = repositorio.registrados.first()
        assertEquals("daniela@ejemplo.mx", recibido.correo)
        assertEquals("Daniela Pérez", recibido.nombreCompleto)
        assertEquals("  Clave Con Espacios  ", recibido.contrasena)
    }

    @Test fun `CP-160i un error del repositorio se propaga sin transformarse`() {
        for (esperado in listOf(ErrorDeRegistro.DemasiadosIntentos, ErrorDeRegistro.SinConexion)) {
            val repositorio = RepositorioDeRegistroFalso().apply { errorAlRegistrar = esperado }
            try {
                correr { caso(repositorio).ejecutar(datos()) }
                fail("Se esperaba $esperado")
            } catch (e: ErrorDeRegistro) {
                assertEquals(esperado, e)
            }
        }
    }

    @Test fun `CP-160i reenviar verificacion propaga el error sin transformarse`() {
        val repositorio = RepositorioDeRegistroFalso().apply { errorAlRegistrar = ErrorDeRegistro.DemasiadosIntentos }
        try {
            correr { ReenviarVerificacionUseCase(repositorio).ejecutar(correo = "daniela@ejemplo.mx") }
            fail("Se esperaba DemasiadosIntentos")
        } catch (e: ErrorDeRegistro) {
            assertEquals(ErrorDeRegistro.DemasiadosIntentos, e)
        }
        assertEquals(listOf("daniela@ejemplo.mx"), repositorio.reenvios)
    }

    @Test fun `CP-160j la descripcion de los datos no contiene la contrasena`() {
        val d = datos(contrasena = "secreta-1234567")
        assertFalse(d.toString().contains("secreta-1234567"))
        assertFalse("$d".contains("secreta-1234567"))
    }

    @Test fun `CP-114a sin aceptar el aviso es aviso no aceptado y el repositorio no recibe nada`() {
        val repositorio = RepositorioDeRegistroFalso()

        assertEquals(listOf(ErrorDeRegistro.AvisoNoAceptado), erroresAlRegistrar(datos(aviso = false), repositorio))
        assertTrue(repositorio.registrados.isEmpty())
    }

    @Test fun `CP-114e sin indicar finalidades las tres quedan desmarcadas`() {
        assertEquals(emptySet<FinalidadSecundaria>(), datos().finalidadesAceptadas)
    }
}
