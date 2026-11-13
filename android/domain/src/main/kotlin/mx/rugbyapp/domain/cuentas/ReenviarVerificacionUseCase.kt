package mx.rugbyapp.domain.cuentas

/** C-01 · «Reenviar enlace» en Verifica tu correo. Espejo en iOS: Domain/Cuentas/ReenviarVerificacionUseCase.swift. */
class ReenviarVerificacionUseCase(private val repositorio: RepositorioDeRegistro) {
    suspend fun ejecutar(correo: String) {
        repositorio.reenviarVerificacion(ValidadorDeRegistro.normalizarCorreo(correo))
    }
}
