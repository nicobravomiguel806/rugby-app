import XCTest
@testable import Domain

/// Contrato de la cola offline (SP-02). Mismos casos que ColaDeSincronizacionTest.kt (CP-130 a CP-135).
final class ColaDeSincronizacionTests: XCTestCase {

    final class AlmacenEnMemoria: AlmacenLocal {
        var orden: [String] = []
        var filas: [String: CambioPendiente] = [:]
        func guardar(_ c: CambioPendiente) { if filas[c.id] == nil { orden.append(c.id) }; filas[c.id] = c }
        func pendientes() -> [CambioPendiente] { orden.compactMap { filas[$0] } }
        func marcarSincronizados(_ ids: Set<String>) { ids.forEach { filas[$0] = nil }; orden.removeAll { ids.contains($0) } }
        func actualizar(_ c: CambioPendiente) { filas[c.id] = c }
    }

    final class ServidorFalso: DestinoRemoto {
        struct SinRed: Error {}
        var recibidos: [String: CambioPendiente] = [:]
        var ordenDeLlegada: [String] = []
        var sinRed = false
        var fallarDespuesDeGuardar = false
        func enviar(_ lote: [CambioPendiente]) throws -> Set<String> {
            if sinRed { throw SinRed() }
            for c in lote where recibidos[c.id] == nil { recibidos[c.id] = c; ordenDeLlegada.append(c.id) }
            if fallarDespuesDeGuardar { fallarDespuesDeGuardar = false; throw SinRed() }
            return Set(lote.map(\.id))
        }
    }

    func test_CP130_sinRedNoSePierdeNada() {
        let almacen = AlmacenEnMemoria(); let cola = ColaDeSincronizacion(almacen: almacen)
        let servidor = ServidorFalso(); servidor.sinRed = true
        ["a", "b", "c"].forEach { cola.encolar(id: $0, payload: "{}") }
        guard case .parcial = cola.sincronizar(con: servidor) else { return XCTFail("Debía quedar parcial") }
        XCTAssertEqual(almacen.pendientes().count, 3)
        XCTAssertTrue(servidor.recibidos.isEmpty)
    }

    func test_CP131_alReconectarLleganUnaSolaVez() {
        let almacen = AlmacenEnMemoria(); let cola = ColaDeSincronizacion(almacen: almacen)
        let servidor = ServidorFalso(); servidor.sinRed = true
        ["a", "b", "c"].forEach { cola.encolar(id: $0, payload: "{}") }
        _ = cola.sincronizar(con: servidor)
        servidor.sinRed = false
        XCTAssertEqual(cola.sincronizar(con: servidor), .completa(enviados: 3))
        XCTAssertEqual(servidor.recibidos.count, 3)
        XCTAssertTrue(almacen.pendientes().isEmpty)
    }

    func test_CP132_respuestaPerdidaNoDuplica() {
        let almacen = AlmacenEnMemoria(); let cola = ColaDeSincronizacion(almacen: almacen)
        let servidor = ServidorFalso(); servidor.fallarDespuesDeGuardar = true
        cola.encolar(id: "a", payload: "{}"); cola.encolar(id: "b", payload: "{}")
        _ = cola.sincronizar(con: servidor)
        XCTAssertEqual(almacen.pendientes().count, 2)
        _ = cola.sincronizar(con: servidor)
        XCTAssertEqual(servidor.recibidos.count, 2)
        XCTAssertTrue(almacen.pendientes().isEmpty)
    }

    func test_CP133_ordenDeCapturaEnVariosLotes() {
        let almacen = AlmacenEnMemoria(); let cola = ColaDeSincronizacion(almacen: almacen, tamanoDeLote: 2)
        let ids = (1...5).map { "ev\($0)" }
        ids.forEach { cola.encolar(id: $0, payload: "{}") }
        let servidor = ServidorFalso()
        _ = cola.sincronizar(con: servidor)
        XCTAssertEqual(servidor.ordenDeLlegada, ids)
    }

    func test_CP134_mismoIdNoDuplica() {
        let almacen = AlmacenEnMemoria(); let cola = ColaDeSincronizacion(almacen: almacen)
        cola.encolar(id: "a", payload: "{}"); cola.encolar(id: "a", payload: "{}")
        XCTAssertEqual(almacen.pendientes().count, 1)
    }

    func test_CP135_backoffExponencialConTope() {
        let cola = ColaDeSincronizacion(almacen: AlmacenEnMemoria())
        XCTAssertEqual((1...8).map { cola.backoff(intentos: $0) }, [1, 2, 4, 8, 16, 32, 60, 60])
    }

    func test_secuenciaContinuaTrasReiniciar() {
        let almacen = AlmacenEnMemoria()
        let primera = ColaDeSincronizacion(almacen: almacen)
        primera.encolar(id: "a", payload: "{}"); primera.encolar(id: "b", payload: "{}")
        XCTAssertEqual(ColaDeSincronizacion(almacen: almacen).encolar(id: "c", payload: "{}").secuencia, 3)
    }
}
