package mx.rugbyapp.data.cuentas

import java.security.SecureRandom
import mx.rugbyapp.domain.cuentas.GeneradorDeNonce

/** SP-04 · Nonce crudo: 32 bytes de SecureRandom en hex (64 caracteres). Espejo: GeneradorDeNonceSeguro.swift. */
class GeneradorDeNonceSeguro(private val aleatorio: SecureRandom = SecureRandom()) : GeneradorDeNonce {
    override fun generar(): String = ByteArray(32).also(aleatorio::nextBytes).joinToString("") { "%02x".format(it) }
}
