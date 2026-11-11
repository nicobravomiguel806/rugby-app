// C-02 · La hora actual en segundos, para que Domain siga sin Foundation y los tests controlen el tiempo (CP-167g).
// Implementación: RugbyApp/Cuentas/RelojDelSistema. Espejo en Android: domain/.../cuentas/Reloj.kt.

public protocol Reloj: Sendable {
    func ahoraEnSegundos() -> Int64
}
