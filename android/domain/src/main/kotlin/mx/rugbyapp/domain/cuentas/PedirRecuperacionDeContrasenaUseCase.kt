package mx.rugbyapp.domain.cuentas

/**
 * C-02 · CA-2: pedir el enlace para restablecer la contraseña. Siempre el mismo resultado, exista o no la cuenta (AT-11).
 * Espejo en iOS: Domain/Cuentas/PedirRecuperacionDeContrasenaUseCase.swift.
 */
class PedirRecuperacionDeContrasenaUseCase(private val repositorio: RepositorioDeRecuperacion) {
    suspend fun ejecutar(correo: String): ResultadoDeRecuperacion {
        val normalizado = ValidadorDeRegistro.normalizarCorreo(correo)
        if (!ValidadorDeRegistro.esCorreoValido(normalizado)) throw ErrorDeRecuperacion.CorreoInvalido
        repositorio.enviarEnlace(normalizado)
        return ResultadoDeRecuperacion.EnlaceEnviado(normalizado)
    }
}
