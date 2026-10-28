// SP-02 · Offline-first: cola de sincronización idempotente.
// Espejo en Android: domain/.../sync/ColaDeSincronizacion.kt — ver docs/adr/0002-offline-first-idempotente.md

public struct CambioPendiente: Equatable, Sendable {
    public let id: String
    public let secuencia: Int64
    public let payload: String
    public var intentos: Int = 0
}

/// Almacenamiento local (SwiftData/GRDB en Data). Solo el protocolo vive en Domain.
public protocol AlmacenLocal: AnyObject {
    func guardar(_ cambio: CambioPendiente)
    func pendientes() -> [CambioPendiente]
    func marcarSincronizados(_ ids: Set<String>)
    func actualizar(_ cambio: CambioPendiente)
}

/// Destino remoto (RPC sync_match_events en Supabase). Devuelve los ids confirmados.
public protocol DestinoRemoto {
    func enviar(_ lote: [CambioPendiente]) throws -> Set<String>
}

public enum ResultadoDeSincronizacion: Equatable {
    case completa(enviados: Int)
    case parcial(enviados: Int, pendientes: Int, reintentarEnSegundos: Int64)
}

public final class ColaDeSincronizacion {
    private let almacen: AlmacenLocal
    private let tamanoDeLote: Int
    private let backoffMaximoSegundos: Int64
    private var siguienteSecuencia: Int64

    public init(almacen: AlmacenLocal, tamanoDeLote: Int = 50, backoffMaximoSegundos: Int64 = 60) {
        self.almacen = almacen
        self.tamanoDeLote = tamanoDeLote
        self.backoffMaximoSegundos = backoffMaximoSegundos
        self.siguienteSecuencia = (almacen.pendientes().map(\.secuencia).max() ?? 0) + 1
    }

    /// Guarda primero en local; nunca espera a la red. Encolar dos veces el mismo id no duplica.
    @discardableResult
    public func encolar(id: String, payload: String) -> CambioPendiente {
        if let existente = almacen.pendientes().first(where: { $0.id == id }) { return existente }
        let cambio = CambioPendiente(id: id, secuencia: siguienteSecuencia, payload: payload)
        siguienteSecuencia += 1
        almacen.guardar(cambio)
        return cambio
    }

    public func sincronizar(con remoto: DestinoRemoto) -> ResultadoDeSincronizacion {
        var enviados = 0
        while true {
            let lote = Array(almacen.pendientes().sorted { $0.secuencia < $1.secuencia }.prefix(tamanoDeLote))
            if lote.isEmpty { return .completa(enviados: enviados) }
            do {
                let confirmados = try remoto.enviar(lote)
                almacen.marcarSincronizados(confirmados)
                enviados += confirmados.count
                if confirmados.count < lote.count {
                    return fallo(lote.filter { !confirmados.contains($0.id) }, enviados: enviados)
                }
            } catch {
                return fallo(lote, enviados: enviados)
            }
        }
    }

    private func fallo(_ noEnviados: [CambioPendiente], enviados: Int) -> ResultadoDeSincronizacion {
        for var c in noEnviados { c.intentos += 1; almacen.actualizar(c) }
        let intentos = almacen.pendientes().map(\.intentos).max() ?? 1
        return .parcial(enviados: enviados, pendientes: almacen.pendientes().count, reintentarEnSegundos: backoff(intentos: intentos))
    }

    /// 1, 2, 4, 8 … hasta backoffMaximoSegundos.
    public func backoff(intentos: Int) -> Int64 {
        let exp = Int64(max(0, min(30, intentos - 1)))
        return min(backoffMaximoSegundos, Int64(1) << exp)
    }
}
