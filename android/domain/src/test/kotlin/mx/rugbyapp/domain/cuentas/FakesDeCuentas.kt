package mx.rugbyapp.domain.cuentas

import kotlin.coroutines.Continuation
import kotlin.coroutines.EmptyCoroutineContext
import kotlin.coroutines.startCoroutine

/**
 * SP-04 · Fakes de los puertos de Cuentas. Registran el orden de las llamadas y sus argumentos.
 * Espejo en iOS: ios/Packages/Domain/Tests/DomainTests/FakesDeCuentas.swift.
 */

/** Corre una función `suspend` sin kotlinx-coroutines (:domain no depende de nada). Los fakes nunca suspenden. */
fun <T> correr(bloque: suspend () -> T): T {
    var resultado: Result<T>? = null
    bloque.startCoroutine(Continuation(EmptyCoroutineContext) { resultado = it })
    return checkNotNull(resultado) { "El bloque quedó suspendido" }.getOrThrow()
}

class Bitacora {
    val llamadas = mutableListOf<String>()
    fun anotar(llamada: String) { llamadas += llamada }
}

class GeneradorFalso(private val valor: String, private val bitacora: Bitacora) : GeneradorDeNonce {
    override fun generar(): String { bitacora.anotar("generar"); return valor }
}

/** Hash falso: no es SHA-256, solo deja ver qué valor llegó a cada puerto. */
class HashFalso(private val bitacora: Bitacora) : HashDeNonce {
    override fun sha256Hex(nonce: String): String { bitacora.anotar("hash($nonce)"); return "hash($nonce)" }
}

class ObtenedorFalso(private val resultado: Result<CredencialNativa>, private val bitacora: Bitacora) : ObtenedorDeCredencial {
    override suspend fun obtener(p: ProveedorDeIdentidad, nonceHasheado: String): CredencialNativa {
        bitacora.anotar("obtener(${p.name.lowercase()},$nonceHasheado)")
        return resultado.getOrThrow()
    }
}

class RepositorioFalso(private val bitacora: Bitacora, guardada: Sesion? = null) : RepositorioDeSesion {
    var resultadoDeInicio: Result<Sesion> = Result.success(Sesion("u-1", "a@b.mx"))
    var errorAlBorrar: ErrorDeAutenticacion? = null
    var guardada: Sesion? = guardada
        private set
    var credencialRecibida: CredencialNativa? = null
        private set
    var nonceRecibido: String? = null
        private set
    // C-02 · Lo que llegó al inicio con correo.
    var correoRecibido: String? = null
        private set
    var contrasenaRecibida: String? = null
        private set

    override suspend fun iniciarSesion(c: CredencialNativa, nonce: String): Sesion {
        bitacora.anotar("iniciarSesion($nonce)")
        credencialRecibida = c
        nonceRecibido = nonce
        return resultadoDeInicio.getOrThrow().also { guardada = it }
    }

    override suspend fun iniciarSesion(correo: String, contrasena: String): Sesion {
        bitacora.anotar("iniciarSesionConCorreo")
        correoRecibido = correo
        contrasenaRecibida = contrasena
        return resultadoDeInicio.getOrThrow().also { guardada = it }
    }

    override suspend fun sesionActual(): Sesion? { bitacora.anotar("sesionActual"); return guardada }

    override suspend fun borrarSesionLocal() {
        bitacora.anotar("borrarSesionLocal")
        errorAlBorrar?.let { throw it }
        guardada = null
    }
}

// C-02 · Fakes de la cola de revocaciones pendientes (ADR 0010), del reloj y de la recuperación de contraseña.

class RelojFalso(private val ahora: Long) : Reloj {
    override fun ahoraEnSegundos(): Long = ahora
}

/** Guarda las pendientes en memoria, sin tokens. `revocar` quita la pendiente si no falla; con error, la deja. */
class RepositorioDeRevocacionesPendientesFalso(
    val bitacora: Bitacora = Bitacora(),
    var ahora: Long = 1_000_000,
    guardadas: List<RevocacionPendiente> = emptyList(),
) : RepositorioDeRevocacionesPendientes {
    var errorAlGuardar: ErrorDeAutenticacion? = null
    /** Error para todas las revocaciones, salvo que `erroresPorId` diga otra cosa. */
    var errorAlRevocar: ErrorDeAutenticacion? = null
    var erroresPorId: Map<String, ErrorDeAutenticacion> = emptyMap()
    private val _guardadas = guardadas.toMutableList()
    val guardadas: List<RevocacionPendiente> get() = _guardadas.toList()
    val revocadas = mutableListOf<RevocacionPendiente>()
    private var contador = 0

    override suspend fun guardar(usuarioId: String, revocarAviso: String?): RevocacionPendiente {
        bitacora.anotar("guardar($usuarioId,${revocarAviso ?: "-"})")
        errorAlGuardar?.let { throw it }
        contador += 1
        return RevocacionPendiente("p-$contador", usuarioId, revocarAviso, ahora).also { _guardadas += it }
    }

    override suspend fun descartar(id: String) {
        bitacora.anotar("descartar($id)")
        _guardadas.removeAll { it.id == id }
    }

    override suspend fun quitarAviso(usuarioId: String) {
        bitacora.anotar("quitarAviso($usuarioId)")
        _guardadas.replaceAll { if (it.usuarioId == usuarioId) it.copy(versionDelAvisoPorRevocar = null) else it }
    }

    override suspend fun pendientes(): List<RevocacionPendiente> = guardadas

    override suspend fun revocar(pendiente: RevocacionPendiente) {
        bitacora.anotar("revocar(${pendiente.id})")
        revocadas += pendiente
        (erroresPorId[pendiente.id] ?: errorAlRevocar)?.let { throw it }
        _guardadas.removeAll { it.id == pendiente.id }
    }
}

class RepositorioDeRecuperacionFalso(
    val bitacora: Bitacora = Bitacora(),
    /** Correos con cuenta. El repositorio responde igual exista o no (AT-11): solo cambia `enviadosAConocidos`. */
    var conocidos: Set<String> = emptySet(),
    enCurso: Boolean = false,
) : RepositorioDeRecuperacion {
    var errorAlEnviar: ErrorDeRecuperacion? = null
    var errorAlConfirmar: ErrorDeRecuperacion? = null
    var errorAlCambiar: ErrorDeRecuperacion? = null
    var errorAlCerrarOtras: ErrorDeRecuperacion? = null
    var sesionAlConfirmar = Sesion("u-1", "daniela@ejemplo.mx")
    var enCurso: Boolean = enCurso
        private set
    val enviados = mutableListOf<String>()
    val enviadosAConocidos = mutableListOf<String>()
    val enlacesRecibidos = mutableListOf<String>()
    val contrasenasRecibidas = mutableListOf<String>()

    override suspend fun enviarEnlace(correo: String) {
        bitacora.anotar("enviarEnlace")
        enviados += correo
        if (correo in conocidos) enviadosAConocidos += correo
        errorAlEnviar?.let { throw it }
    }

    override suspend fun confirmarEnlace(enlace: String): Sesion {
        bitacora.anotar("confirmarEnlace")
        enlacesRecibidos += enlace
        errorAlConfirmar?.let { throw it }
        enCurso = true
        return sesionAlConfirmar
    }

    override suspend fun cambiarContrasena(nueva: String) {
        bitacora.anotar("cambiarContrasena")
        contrasenasRecibidas += nueva
        errorAlCambiar?.let { throw it }
    }

    override suspend fun cerrarOtrasSesiones() {
        bitacora.anotar("cerrarOtrasSesiones")
        errorAlCerrarOtras?.let { throw it }
    }

    override suspend fun recuperacionEnCurso(): Boolean = enCurso

    override suspend fun terminarRecuperacion() {
        bitacora.anotar("terminarRecuperacion")
        enCurso = false
    }
}

/** C-02 · Arma `CerrarSesionUseCase` con sus dos puertos y el reintento, como lo compone App. */
fun cerrarSesion(
    sesiones: RepositorioFalso,
    pendientes: RepositorioDeRevocacionesPendientesFalso = RepositorioDeRevocacionesPendientesFalso(),
) = CerrarSesionUseCase(sesiones, pendientes, ReintentarRevocacionesPendientesUseCase(pendientes, RelojFalso(pendientes.ahora)))

// C-01 · Fakes de RepositorioDeRegistro y RepositorioDeConsentimiento. Cuentan las llamadas y guardan lo recibido.

class RepositorioDeRegistroFalso : RepositorioDeRegistro {
    var errorAlRegistrar: ErrorDeRegistro? = null
    var errorAlConfirmar: ErrorDeRegistro? = null
    var sesionAlConfirmar = Sesion("u-1", "daniela@ejemplo.mx", nombre = "Daniela")
    val registrados = mutableListOf<DatosDeRegistro>()
    val reenvios = mutableListOf<String>()
    val enlacesRecibidos = mutableListOf<String>()

    override suspend fun registrar(datos: DatosDeRegistro): ResultadoDeRegistro {
        registrados += datos
        errorAlRegistrar?.let { throw it }
        return ResultadoDeRegistro.EnlaceEnviado(datos.correo)
    }

    override suspend fun reenviarVerificacion(correo: String) {
        reenvios += correo
        errorAlRegistrar?.let { throw it }
    }

    override suspend fun confirmarCorreo(enlace: String): Sesion {
        enlacesRecibidos += enlace
        errorAlConfirmar?.let { throw it }
        return sesionAlConfirmar
    }
}

class RepositorioDeConsentimientoFalso(
    aceptadas: Set<String> = emptySet(),
    private val bitacora: Bitacora? = null,
) : RepositorioDeConsentimiento {
    var errorAlAceptar: ErrorDeConsentimiento? = null
    var errorAlConsultar: ErrorDeConsentimiento? = null
    var errorAlRevocar: ErrorDeConsentimiento? = null
    /** H-6 · Se ejecuta durante la consulta, antes de responder (p. ej., llega el enlace del correo a media consulta). */
    var alConsultar: (() -> Unit)? = null
    /** Versiones del aviso que el "servidor" tiene aceptadas (estado vigente). */
    val aceptadas = aceptadas.toMutableSet()
    val llamadasAAceptar = mutableListOf<Pair<String, Set<FinalidadSecundaria>>>()
    val versionesConsultadas = mutableListOf<String>()
    val revocaciones = mutableListOf<String>()

    override suspend fun revocarAviso(version: String) {
        bitacora?.anotar("revocarAviso")
        revocaciones += version
        errorAlRevocar?.let { throw it }
        aceptadas -= version
    }

    override suspend fun aceptarAviso(version: String, finalidades: Set<FinalidadSecundaria>) {
        llamadasAAceptar += version to finalidades
        errorAlAceptar?.let { throw it }
        aceptadas += version
    }

    override suspend fun avisoAceptado(version: String): Boolean {
        bitacora?.anotar("avisoAceptado")
        versionesConsultadas += version
        alConsultar?.invoke()
        errorAlConsultar?.let { throw it }
        return version in aceptadas
    }
}
