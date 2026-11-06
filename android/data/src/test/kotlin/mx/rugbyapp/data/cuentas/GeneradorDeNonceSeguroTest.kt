package mx.rugbyapp.data.cuentas

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** SP-04 · El nonce crudo es aleatorio: 64 caracteres hex y distinto en cada llamada. Mismo caso que GeneradorDeNonceSeguroTests.swift. */
class GeneradorDeNonceSeguroTest {
    @Test fun `dos llamadas dan nonces distintos de 64 caracteres hex`() {
        val generador = GeneradorDeNonceSeguro()
        val a = generador.generar()
        val b = generador.generar()

        assertNotEquals(a, b)
        listOf(a, b).forEach { nonce ->
            assertEquals(64, nonce.length)
            assertTrue(nonce.all { it in "0123456789abcdef" })
        }
    }
}
