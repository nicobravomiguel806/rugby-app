import XCTest
@testable import Data

/// SP-04 · El nonce crudo es aleatorio: 64 caracteres hex y distinto en cada llamada. Mismo caso que GeneradorDeNonceSeguroTest.kt.
final class GeneradorDeNonceSeguroTests: XCTestCase {
    func test_dosLlamadasDanNoncesDistintosDe64CaracteresHex() {
        let generador = GeneradorDeNonceSeguro()
        let a = generador.generar(), b = generador.generar()

        XCTAssertNotEqual(a, b)
        for nonce in [a, b] {
            XCTAssertEqual(nonce.count, 64)
            XCTAssertTrue(nonce.allSatisfy { "0123456789abcdef".contains($0) })
        }
    }
}
