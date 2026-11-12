package mx.rugbyapp.presentation.cuentas

import mx.rugbyapp.domain.cuentas.CerrarSesionUseCase
import mx.rugbyapp.domain.cuentas.CredencialNativa
import mx.rugbyapp.domain.cuentas.DatosDeRegistro
import mx.rugbyapp.domain.cuentas.ErrorDeAutenticacion
import mx.rugbyapp.domain.cuentas.ErrorDeConsentimiento
import mx.rugbyapp.domain.cuentas.ErrorDeRecuperacion
import mx.rugbyapp.domain.cuentas.ErrorDeRegistro
import mx.rugbyapp.domain.cuentas.FinalidadSecundaria
import mx.rugbyapp.domain.cuentas.GeneradorDeNonce
import mx.rugbyapp.domain.cuentas.HashDeNonce
import mx.rugbyapp.domain.cuentas.IniciarSesionUseCase
import mx.rugbyapp.domain.cuentas.ObtenedorDeCredencial
import mx.rugbyapp.domain.cuentas.ProveedorDeIdentidad
import mx.rugbyapp.domain.cuentas.ReintentarRevocacionesPendientesUseCase
import mx.rugbyapp.domain.cuentas.RepositorioDeConsentimiento
import mx.rugbyapp.domain.cuentas.RepositorioDeRecuperacion
import mx.rugbyapp.domain.cuentas.RepositorioDeRegistro
import mx.rugbyapp.domain.cuentas.RepositorioDeRevocacionesPendientes
import mx.rugbyapp.domain.cuentas.RepositorioDeSesion
import mx.rugbyapp.domain.cuentas.ResultadoDeRegistro
import mx.rugbyapp.domain.cuentas.RevocacionPendiente
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
    var errorAlRevocar: ErrorDeConsentimiento? = null
    var revocaciones = 0
    override suspend fun revocarAviso(version: String) { revocaciones++; errorAlRevocar?.let { throw it }; aceptado = false }
}

class SesionFalsa(var guardada: Sesion? = null) : RepositorioDeSesion {
    var errorAlBorrar: ErrorDeAutenticacion? = null
    /** C-02 · Resultado del inicio con correo. */
    var resultadoConCorreo: Result<Sesion> = Result.success(Sesion("u-1", "daniela@ejemplo.mx"))
    var borrados = 0
    val correosRecibidos = mutableListOf<String>()
    override suspend fun iniciarSesion(c: CredencialNativa, nonce: String) = Sesion("g-1", "g@gmail.com", nombre = "Gabriel").also { guardada = it }
    override suspend fun iniciarSesion(correo: String, contrasena: String): Sesion {
        correosRecibidos += correo
        return resultadoConCorreo.getOrThrow().also { guardada = it }
    }
    override suspend fun sesionActual() = guardada
    override suspend fun borrarSesionLocal() { borrados++; errorAlBorrar?.let { throw it }; guardada = null }
}

// C-02 · Fakes de las revocaciones pendientes (sin red: nunca revocan) y de la recuperación.

class PendientesFalsas : RepositorioDeRevocacionesPendientes {
    val guardadas = mutableListOf<RevocacionPendiente>()
    override suspend fun guardar(usuarioId: String, revocarAviso: String?) =
        RevocacionPendiente("p-${guardadas.size + 1}", usuarioId, revocarAviso, 1_000).also { guardadas += it }
    override suspend fun descartar(id: String) { guardadas.removeAll { it.id == id } }
    override suspend fun quitarAviso(usuarioId: String) = Unit
    override suspend fun pendientes(): List<RevocacionPendiente> = guardadas.toList()
    override suspend fun revocar(pendiente: RevocacionPendiente) { throw ErrorDeAutenticacion.SinConexion }
}

class RecuperacionFalsa : RepositorioDeRecuperacion {
    var errorAlEnviar: ErrorDeRecuperacion? = null
    var errorAlConfirmar: ErrorDeRecuperacion? = null
    var errorAlCambiar: ErrorDeRecuperacion? = null
    var enCurso = false
    val enviados = mutableListOf<String>()
    val cambios = mutableListOf<String>()
    val enlaces = mutableListOf<String>()
    val sesion = Sesion("u-1", "daniela@ejemplo.mx")
    override suspend fun enviarEnlace(correo: String) { enviados += correo; errorAlEnviar?.let { throw it } }
    override suspend fun confirmarEnlace(enlace: String): Sesion { enlaces += enlace; errorAlConfirmar?.let { throw it }; enCurso = true; return sesion }
    override suspend fun cambiarContrasena(nueva: String) { cambios += nueva; errorAlCambiar?.let { throw it } }
    override suspend fun cerrarOtrasSesiones() = Unit
    override suspend fun recuperacionEnCurso() = enCurso
    override suspend fun terminarRecuperacion() { enCurso = false }
}

/** Casos de uso armados como en App, con las pendientes sin red. */
object Armar {
    fun reintentar(pendientes: PendientesFalsas) = ReintentarRevocacionesPendientesUseCase(pendientes) { 1_000 }
    fun cerrarSesion(sesiones: RepositorioDeSesion, pendientes: PendientesFalsas = PendientesFalsas()) =
        CerrarSesionUseCase(sesiones, pendientes, reintentar(pendientes))
    fun google(sesiones: RepositorioDeSesion, error: ErrorDeAutenticacion? = null, pendientes: PendientesFalsas = PendientesFalsas()) =
        IniciarSesionUseCase(GeneradorFijo, HashFijo, GoogleFalso(error), sesiones, pendientes, reintentar(pendientes), ConsentimientoFalso())
}

object GeneradorFijo : GeneradorDeNonce { override fun generar() = "crudo" }
object HashFijo : HashDeNonce { override fun sha256Hex(nonce: String) = "hash" }
class GoogleFalso(private val error: ErrorDeAutenticacion? = null) : ObtenedorDeCredencial {
    override suspend fun obtener(p: ProveedorDeIdentidad, nonceHasheado: String): CredencialNativa {
        error?.let { throw it }
        return CredencialNativa(p, "id", null)
    }
}
