import XCTest
@testable import Data

/// SP-04 · CP-159 (parte de Data): vector conocido de SHA-256. Mismo caso que HashDeNonceSHA256Test.kt.
final class HashDeNonceSHA256Tests: XCTestCase {
    func test_CP159_sha256HexDeAbcCoincideConElVectorConocido() {
        let hash = HashDeNonceSHA256().sha256Hex("abc")

        XCTAssertEqual(hash, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        XCTAssertEqual(hash.count, 64)
        XCTAssertEqual(hash, hash.lowercased())
    }
}
