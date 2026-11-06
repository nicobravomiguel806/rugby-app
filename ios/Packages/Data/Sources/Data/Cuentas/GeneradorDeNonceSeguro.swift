// SP-04 · Nonce crudo: 32 bytes de SecRandomCopyBytes en hex (64 caracteres). Si el sistema no da aleatoriedad,
// devuelve vacío e IniciarSesionUseCase rechaza el inicio (P-9). Espejo en Android: data/.../cuentas/GeneradorDeNonceSeguro.kt.
import Foundation
import Security
import Domain

public struct GeneradorDeNonceSeguro: GeneradorDeNonce {
    public init() {}

    public func generar() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { return "" }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }
}
