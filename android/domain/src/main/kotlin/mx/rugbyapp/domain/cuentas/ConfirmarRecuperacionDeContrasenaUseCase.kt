package mx.rugbyapp.domain.cuentas

/**
 * C-02 · CA-2: el enlace de recuperación (`rugbyapp://recuperar-contrasena?code=…`) abre una sesión de recuperación y
 * deja la marca «recuperación en curso» (CP-166d). Espejo en iOS: Domain/Cuentas/ConfirmarRecuperacionDeContrasenaUseCase.swift.
 */
class ConfirmarRecuperacionDeContrasenaUseCase(private val repositorio: RepositorioDeRecuperacion) {
    suspend fun ejecutar(enlace: String): Sesion = repositorio.confirmarEnlace(enlace)
}
