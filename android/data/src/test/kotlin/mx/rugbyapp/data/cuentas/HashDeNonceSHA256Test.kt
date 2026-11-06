package mx.rugbyapp.data.cuentas

import org.junit.Assert.assertEquals
import org.junit.Test

/** SP-04 · CP-159 (parte de Data): vector conocido de SHA-256. Mismo caso que HashDeNonceSHA256Tests.swift. */
class HashDeNonceSHA256Test {
    @Test fun `CP-159 sha256 hex de abc coincide con el vector conocido`() {
        val hash = HashDeNonceSHA256().sha256Hex("abc")

        assertEquals("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", hash)
        assertEquals(64, hash.length)
        assertEquals(hash.lowercase(), hash)
    }
}
