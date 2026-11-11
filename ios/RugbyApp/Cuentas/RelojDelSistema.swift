import Foundation
import Domain

/// C-02 · Reloj real para la vigencia de 7 días de las revocaciones pendientes (ADR 0010). Domain no usa Foundation.
/// Espejo en Android: app/cuentas/RelojDelSistema.kt.
struct RelojDelSistema: Reloj {
    func ahoraEnSegundos() -> Int64 { Int64(Date().timeIntervalSince1970) }
}
