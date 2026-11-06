// SP-04 · SHA-256 del nonce en hex en minúsculas (CP-159). Es lo que recibe Google; Supabase recibe el crudo.
// Espejo en Android: data/.../cuentas/HashDeNonceSHA256.kt.
import CryptoKit
import Foundation
import Domain

public struct HashDeNonceSHA256: HashDeNonce {
    public init() {}

    public func sha256Hex(_ nonce: String) -> String {
        SHA256.hash(data: Data(nonce.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
