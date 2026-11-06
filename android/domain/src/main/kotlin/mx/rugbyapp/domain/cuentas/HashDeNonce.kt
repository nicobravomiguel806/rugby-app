package mx.rugbyapp.domain.cuentas

/** SP-04 · Puerto: SHA-256 del nonce en hex en minúsculas. La criptografía vive en :data (HashDeNonceSHA256). */
interface HashDeNonce {
    fun sha256Hex(nonce: String): String
}
