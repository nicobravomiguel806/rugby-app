// C-01 · Registro con correo (CA-1, CA-3; domain-model.md §1). Valida y, solo si no hay errores, normaliza y
// llama al repositorio. Espejo en Android: domain/.../cuentas/RegistrarUsuarioUseCase.kt.

public struct RegistrarUsuarioUseCase: Sendable {
    private let validador: ValidadorDeRegistro
    private let repositorio: RepositorioDeRegistro

    public init(validador: ValidadorDeRegistro, repositorio: RepositorioDeRegistro) {
        self.validador = validador
        self.repositorio = repositorio
    }

    /// Lanza `ErroresDeValidacion` con todos los errores del formulario, o el `ErrorDeRegistro` del repositorio.
    public func ejecutar(_ datos: DatosDeRegistro) async throws -> ResultadoDeRegistro {
        let errores = validador.validar(datos)
        guard errores.isEmpty else { throw ErroresDeValidacion(errores: errores) }
        return try await repositorio.registrar(validador.normalizar(datos))
    }
}
