package mx.rugbyapp.domain.cuentas

/**
 * C-01 · «Reenviar enlace» en Verifica tu correo. C-02 · También desde Enlace inválido (CA-8), donde la persona puede
 * escribir el correo: uno con formato inválido no llega al servidor (CP-169).
 * Espejo en iOS: Domain/Cuentas/ReenviarVerificacionUseCase.swift.
 */
class ReenviarVerificacionUseCase(private val repositorio: RepositorioDeRegistro) {
    suspend fun ejecutar(correo: String) {
        val normalizado = ValidadorDeRegistro.normalizarCorreo(correo)
        if (!ValidadorDeRegistro.esCorreoValido(normalizado)) throw ErrorDeRegistro.CorreoInvalido
        repositorio.reenviarVerificacion(normalizado)
    }
}
