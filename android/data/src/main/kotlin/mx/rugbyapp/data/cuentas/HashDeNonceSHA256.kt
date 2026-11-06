package mx.rugbyapp.data.cuentas

import java.security.MessageDigest
import mx.rugbyapp.domain.cuentas.HashDeNonce

/** SP-04 · SHA-256 del nonce en hex en minúsculas (CP-159). Lo recibe Google; Supabase recibe el crudo. Espejo: HashDeNonceSHA256.swift. */
class HashDeNonceSHA256 : HashDeNonce {
    override fun sha256Hex(nonce: String): String =
        MessageDigest.getInstance("SHA-256").digest(nonce.toByteArray(Charsets.UTF_8)).joinToString("") { "%02x".format(it) }
}
