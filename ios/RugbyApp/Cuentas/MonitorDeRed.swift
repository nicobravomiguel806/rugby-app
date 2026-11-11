import Foundation
import Network

/// C-02 · CA-4 (ADR 0010): avisa cuando vuelve la red para reintentar las revocaciones pendientes. Solo dispara en la
/// transición «sin red → con red», no en cada cambio de interfaz. Espejo en Android: app/cuentas/MonitorDeRed.kt.
final class MonitorDeRed: @unchecked Sendable {
    private let monitor = NWPathMonitor()
    private let cola = DispatchQueue(label: "mx.rugbyapp.monitor-de-red")
    private var conRed: Bool?

    func empezar(alVolverLaRed: @escaping @Sendable () -> Void) {
        monitor.pathUpdateHandler = { [weak self] ruta in
            guard let self else { return }
            let ahora = ruta.status == .satisfied
            let antes = self.conRed
            self.conRed = ahora
            if ahora, antes == false { alVolverLaRed() }
        }
        monitor.start(queue: cola)
    }

    deinit { monitor.cancel() }
}
