// SP-04 · La sesión guardada en el dispositivo (CP-154). Espejo en Android: domain/.../cuentas/ObtenerSesionActualUseCase.kt.

public struct ObtenerSesionActualUseCase: Sendable {
    private let repositorio: RepositorioDeSesion

    public init(repositorio: RepositorioDeSesion) {
        self.repositorio = repositorio
    }

    public func ejecutar() async -> Sesion? {
        await repositorio.sesionActual()
    }
}
