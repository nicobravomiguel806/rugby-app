package mx.rugbyapp.domain.cuentas

/** C-01 · El enlace del correo inicia la sesión (CA-1, CP-160h, ADR 0008). Espejo en iOS: Domain/Cuentas/ConfirmarCorreoUseCase.swift. */
class ConfirmarCorreoUseCase(private val repositorio: RepositorioDeRegistro) {
    suspend fun ejecutar(enlace: String): Sesion = repositorio.confirmarCorreo(enlace)
}
