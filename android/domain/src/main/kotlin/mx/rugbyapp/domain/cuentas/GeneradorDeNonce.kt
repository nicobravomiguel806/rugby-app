package mx.rugbyapp.domain.cuentas

/** SP-04 · Puerto: genera el nonce crudo. La aleatoriedad vive en :data (GeneradorDeNonceSeguro). */
interface GeneradorDeNonce {
    fun generar(): String
}
