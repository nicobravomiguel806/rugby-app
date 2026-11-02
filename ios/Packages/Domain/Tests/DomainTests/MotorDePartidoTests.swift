import XCTest
@testable import Domain

/// Contrato del motor de reglas (SP-01). Mismos casos que MotorDePartidoTest.kt (CP-120 a CP-128).
final class MotorDePartidoTests: XCTestCase {
    private var n = 0
    private func motor(_ m: Modalidad) -> MotorDePartido { MotorDePartido(reglas: .porDefecto(m)) }
    private func ev(_ tipo: TipoEvento, _ lado: Lado = .local, min: Int = 1, jugador: Int? = nil, anula: String? = nil) -> EventoDePartido {
        n += 1
        return EventoDePartido(id: "e\(n)", tipo: tipo, lado: lado, jugador: jugador, minuto: min, anulaA: anula)
    }

    func test_CP120_ensayoVale5EnXVyEn7s() throws {
        XCTAssertEqual(try motor(.fifteens).calcular([ev(.ensayo)]).local.puntos, 5)
        XCTAssertEqual(try motor(.sevens).calcular([ev(.ensayo)]).local.puntos, 5)
    }

    func test_CP121_rugby13EnsayoVale4YDrop1() throws {
        XCTAssertEqual(try motor(.league13).calcular([ev(.ensayo), ev(.drop, min: 5)]).local.puntos, 5)
    }

    func test_CP122_conversionSoloDespuesDeEnsayo() throws {
        let m = motor(.fifteens)
        XCTAssertEqual(try m.calcular([ev(.ensayo), ev(.conversion, min: 2)]).local.puntos, 7)
        XCTAssertThrowsError(try m.calcular([ev(.conversion)])) { XCTAssertEqual($0 as? ErrorDeRegla, .conversionSinEnsayo) }
        XCTAssertThrowsError(try m.calcular([ev(.ensayo, min: 1), ev(.penal, .visita, min: 2), ev(.conversion, min: 3)])) {
            XCTAssertEqual($0 as? ErrorDeRegla, .conversionSinEnsayo)
        }
    }

    func test_CP123_rojaDejaAlEquipoCon14() throws {
        let e = try motor(.fifteens).calcular([ev(.tarjetaRoja, min: 20, jugador: 4)], alMinuto: 80)
        XCTAssertEqual(e.local.enCancha, 14)
        XCTAssertEqual(e.visita.enCancha, 15)
    }

    func test_CP124_amarillaDura2MinEn7sY10EnXV() throws {
        let amarilla = [ev(.tarjetaAmarilla, min: 4, jugador: 3)]
        XCTAssertEqual(try motor(.sevens).calcular(amarilla, alMinuto: 5).local.enCancha, 6)
        XCTAssertEqual(try motor(.sevens).calcular(amarilla, alMinuto: 6).local.enCancha, 7)
        XCTAssertEqual(try motor(.fifteens).calcular(amarilla, alMinuto: 13).local.enCancha, 14)
        XCTAssertEqual(try motor(.fifteens).calcular(amarilla, alMinuto: 14).local.enCancha, 15)
    }

    func test_CP125_jugadorExpulsadoNoPuedeAnotar() {
        XCTAssertThrowsError(try motor(.fifteens).calcular([ev(.tarjetaRoja, min: 10, jugador: 9), ev(.ensayo, min: 30, jugador: 9)])) {
            XCTAssertEqual($0 as? ErrorDeRegla, .jugadorExpulsado(9))
        }
    }

    func test_CP126_eventoAnuladoNoSumaPeroSeConserva() throws {
        let ensayo = ev(.ensayo, min: 10)
        let eventos = [ensayo, ev(.anulacion, min: 11, anula: ensayo.id)]
        XCTAssertEqual(try motor(.fifteens).calcular(eventos).local.puntos, 0)
        XCTAssertEqual(eventos.count, 2)
        XCTAssertThrowsError(try motor(.fifteens).calcular([ev(.anulacion, anula: "no-existe")]))
    }

    func test_CP127_festivalesSinMarcador() {
        XCTAssertFalse(ReglasDeModalidad.porDefecto(.festival).llevaMarcador)
        XCTAssertThrowsError(try motor(.festival).calcular([ev(.ensayo)]))
        XCTAssertThrowsError(try motor(.league13).calcular([ev(.ensayoDePenal)]))
    }

    func test_CP128_cambiosRespetanLimite() throws {
        let cambios = (1...6).map { ev(.cambio, min: 30 + $0, jugador: $0) }
        XCTAssertThrowsError(try motor(.sevens).calcular(cambios)) { XCTAssertEqual($0 as? ErrorDeRegla, .sinCambiosDisponibles) }
        XCTAssertEqual(try motor(.sevens).calcular(Array(cambios.prefix(5))).local.cambiosUsados, 5)
    }

    func test_modalidadDesdeCodigo() throws {
        XCTAssertEqual(try Modalidad.desdeCodigo("10"), .tens)
        XCTAssertThrowsError(try Modalidad.desdeCodigo("12"))
    }
}
