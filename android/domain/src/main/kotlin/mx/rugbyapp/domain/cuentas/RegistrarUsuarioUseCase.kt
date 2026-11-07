package mx.rugbyapp.domain.cuentas

/**
 * C-01 · Registro con correo (CA-1, CA-3; domain-model.md §1). Valida y, solo si no hay errores, normaliza y llama al
 * repositorio. Espejo en iOS: Domain/Cuentas/RegistrarUsuarioUseCase.swift.
 */
class RegistrarUsuarioUseCase(
    private val validador: ValidadorDeRegistro,
    private val repositorio: RepositorioDeRegistro,
) {
    /** Lanza [ErroresDeValidacion] con todos los errores del formulario, o el [ErrorDeRegistro] del repositorio. */
    suspend fun ejecutar(datos: DatosDeRegistro): ResultadoDeRegistro {
        val errores = validador.validar(datos)
        if (errores.isNotEmpty()) throw ErroresDeValidacion(errores)
        return repositorio.registrar(validador.normalizar(datos))
    }
}
