// C-02 · CA-4, CA-7 (ADR 0010): reintenta las revocaciones pendientes en orden de alta. Descarta sin usar el token las
// que tienen 7 días o más (P-3) y revoca las demás. Una falla no detiene las otras y el caso de uso nunca lanza:
// la red no bloquea a la persona (P-4). El tope de 10 s al arrancar lo pone App.
// Espejo en Android: domain/.../cuentas/ReintentarRevocacionesPendientesUseCase.kt.

public struct ReintentarRevocacionesPendientesUseCase: Sendable {
    private let pendientes: RepositorioDeRevocacionesPendientes
    private let reloj: Reloj

    public init(pendientes: RepositorioDeRevocacionesPendientes, reloj: Reloj) {
        self.pendientes = pendientes
        self.reloj = reloj
    }

    @discardableResult
    public func ejecutar() async -> ResultadoDeReintento {
        let ahora = reloj.ahoraEnSegundos()
        var revocadas = 0, vencidas = 0, siguen = 0
        let enOrden = await pendientes.pendientes().enumerated()
            .sorted { ($0.element.creadaEnSegundos, $0.offset) < ($1.element.creadaEnSegundos, $1.offset) }
            .map(\.element)
        for pendiente in enOrden {
            if ahora - pendiente.creadaEnSegundos >= RevocacionPendiente.vigenciaEnSegundos {
                try? await pendientes.descartar(id: pendiente.id)
                vencidas += 1
                continue
            }
            do {
                try await pendientes.revocar(pendiente)
                revocadas += 1
            } catch {
                siguen += 1
            }
        }
        return ResultadoDeReintento(revocadas: revocadas, vencidas: vencidas, pendientes: siguen)
    }
}
