// C-02 · D-5: inicio de sesión con correo y contraseña (domain-model.md §1). El correo se normaliza y se valida; la
// contraseña no puede estar vacía y no tiene regla de longitud (la decide el servidor). Antes de iniciar reintenta las
// revocaciones pendientes; después, las de la misma cuenta pierden el aviso (P-4, CP-165d/e).
// Espejo en Android: domain/.../cuentas/IniciarSesionConCorreoUseCase.kt.

public struct IniciarSesionConCorreoUseCase: Sendable {
    private let repositorio: RepositorioDeSesion
    private let pendientes: RepositorioDeRevocacionesPendientes
    private let reintentar: ReintentarRevocacionesPendientesUseCase

    public init(
        repositorio: RepositorioDeSesion,
        pendientes: RepositorioDeRevocacionesPendientes,
        reintentar: ReintentarRevocacionesPendientesUseCase
    ) {
        self.repositorio = repositorio
        self.pendientes = pendientes
        self.reintentar = reintentar
    }

    public func ejecutar(_ credenciales: CredencialesDeCorreo) async throws -> Sesion {
        let correo = ValidadorDeRegistro.normalizarCorreo(credenciales.correo)
        guard ValidadorDeRegistro.esCorreoValido(correo) else { throw ErrorDeAutenticacion.correoInvalido }
        guard !credenciales.contrasena.isEmpty else { throw ErrorDeAutenticacion.credencialRechazada }

        await reintentar.ejecutar()
        let sesion = try await repositorio.iniciarSesion(correo: correo, contrasena: credenciales.contrasena)
        try? await pendientes.quitarAviso(usuarioId: sesion.usuarioId)
        return sesion
    }
}
