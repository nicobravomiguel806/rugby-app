// SP-04 · Regla de domain-model.md §1: cerrar sesión cierra solo este dispositivo. Primero borra siempre la sesión
// local, aunque no haya red, y después intenta revocarla (CP-155).
// C-02 · CA-3, CA-4 (ADR 0010): antes de borrar, guarda la revocación pendiente (refresh token cifrado en el almacén
// seguro, solo para revocar). Si el borrado local falla, descarta la pendiente y propaga el error sin transformarse.
// Después reintenta las pendientes; la red nunca lo hace fallar (CP-167).
// Espejo en Android: domain/.../cuentas/CerrarSesionUseCase.kt.

public struct CerrarSesionUseCase: Sendable {
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

    /// `revocarAviso`: versión del aviso que también hay que revocar en el servidor (CA-7), o `nil`.
    public func ejecutar(revocarAviso version: String? = nil) async throws {
        var guardada: RevocacionPendiente?
        if let sesion = await repositorio.sesionActual() {
            guardada = try? await pendientes.guardar(para: sesion.usuarioId, revocarAviso: version)
        }
        do {
            try await repositorio.borrarSesionLocal()
        } catch {
            if let guardada { try? await pendientes.descartar(id: guardada.id) }
            throw error
        }
        await reintentar.ejecutar()
    }
}
