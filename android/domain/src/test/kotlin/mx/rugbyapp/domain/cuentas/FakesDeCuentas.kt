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
    var errorAlRevocar: ErrorDeAutenticacion? = null
    var guardada: Sesion? = guardada
        private set
    var credencialRecibida: CredencialNativa? = null
        private set
    var nonceRecibido: String? = null
        private set

    override suspend fun iniciarSesion(c: CredencialNativa, nonce: String): Sesion {
        bitacora.anotar("iniciarSesion($nonce)")
        credencialRecibida = c
        nonceRecibido = nonce
        return resultadoDeInicio.getOrThrow().also { guardada = it }
    }

    override suspend fun sesionActual(): Sesion? { bitacora.anotar("sesionActual"); return guardada }

    override suspend fun borrarSesionLocal() {
        bitacora.anotar("borrarSesionLocal")
        errorAlBorrar?.let { throw it }
        guardada = null
    }

    override suspend fun revocarSesionEnServidor() {
        bitacora.anotar("revocarSesionEnServidor")
        errorAlRevocar?.let { throw it }
    }
}
