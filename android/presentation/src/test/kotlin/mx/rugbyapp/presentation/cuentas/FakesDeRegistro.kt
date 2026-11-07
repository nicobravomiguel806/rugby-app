package mx.rugbyapp.presentation.cuentas

import mx.rugbyapp.domain.cuentas.CredencialNativa
import mx.rugbyapp.domain.cuentas.DatosDeRegistro
import mx.rugbyapp.domain.cuentas.ErrorDeAutenticacion
import mx.rugbyapp.domain.cuentas.ErrorDeConsentimiento
import mx.rugbyapp.domain.cuentas.ErrorDeRegistro
import mx.rugbyapp.domain.cuentas.FinalidadSecundaria
import mx.rugbyapp.domain.cuentas.GeneradorDeNonce
import mx.rugbyapp.domain.cuentas.HashDeNonce
import mx.rugbyapp.domain.cuentas.ObtenedorDeCredencial
import mx.rugbyapp.domain.cuentas.ProveedorDeIdentidad
import mx.rugbyapp.domain.cuentas.RepositorioDeConsentimiento
import mx.rugbyapp.domain.cuentas.RepositorioDeRegistro
import mx.rugbyapp.domain.cuentas.RepositorioDeSesion
import mx.rugbyapp.domain.cuentas.ResultadoDeRegistro
import mx.rugbyapp.domain.cuentas.Sesion

// C-01 · Fakes de los puertos que usan RegistroViewModel y AvisoDePrivacidadViewModel.
// Espejo en iOS: ios/Packages/Presentation/Tests/PresentationTests/FakesDeRegistro.swift.

class RegistroFalso : RepositorioDeRegistro {
    var error: ErrorDeRegistro? = null
    var errorAlConfirmar: ErrorDeRegistro? = null
    val registrados = mutableListOf<DatosDeRegistro>()
    val reenvios = mutableListOf<String>()
    val sesion = Sesion("u-1", "daniela@ejemplo.mx", nombre = "Daniela")

    override suspend fun registrar(datos: DatosDeRegistro): ResultadoDeRegistro {
        registrados += datos
        error?.let { throw it }
        return ResultadoDeRegistro.EnlaceEnviado(datos.correo)
    }
    override suspend fun reenviarVerificacion(correo: String) { reenvios += correo; error?.let { throw it } }
    override suspend fun confirmarCorreo(enlace: String): Sesion { errorAlConfirmar?.let { throw it }; return sesion }
}

class ConsentimientoFalso : RepositorioDeConsentimiento {
    var errorAlAceptar: ErrorDeConsentimiento? = null
    var errorAlConsultar: ErrorDeConsentimiento? = null
    var aceptado = false
    val aceptaciones = mutableListOf<Set<FinalidadSecundaria>>()
    override suspend fun aceptarAviso(version: String, finalidades: Set<FinalidadSecundaria>) {
        aceptaciones += finalidades
        errorAlAceptar?.let { throw it }
        aceptado = true
    }
    override suspend fun avisoAceptado(version: String): Boolean { errorAlConsultar?.let { throw it }; return aceptado }
}

class SesionFalsa(var guardada: Sesion? = null) : RepositorioDeSesion {
    var errorAlBorrar: ErrorDeAutenticacion? = null
    var borrados = 0
    override suspend fun iniciarSesion(c: CredencialNativa, nonce: String) = Sesion("g-1", "g@gmail.com", nombre = "Gabriel").also { guardada = it }
    override suspend fun sesionActual() = guardada
    override suspend fun borrarSesionLocal() { borrados++; errorAlBorrar?.let { throw it }; guardada = null }
    override suspend fun revocarSesionEnServidor() { throw ErrorDeAutenticacion.SinConexion }
}

object GeneradorFijo : GeneradorDeNonce { override fun generar() = "crudo" }
object HashFijo : HashDeNonce { override fun sha256Hex(nonce: String) = "hash" }
class GoogleFalso(private val error: ErrorDeAutenticacion? = null) : ObtenedorDeCredencial {
    override suspend fun obtener(p: ProveedorDeIdentidad, nonceHasheado: String): CredencialNativa {
        error?.let { throw it }
        return CredencialNativa(p, "id", null)
    }
}
