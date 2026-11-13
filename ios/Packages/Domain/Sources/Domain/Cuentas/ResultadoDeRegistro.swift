// C-01 · Resultado del registro con correo. Es el mismo para un correo nuevo y para uno que ya tiene cuenta
// (P-7, AT-11): la app nunca confirma si un correo existe. Espejo en Android: domain/.../cuentas/ResultadoDeRegistro.kt.

public enum ResultadoDeRegistro: Equatable, Sendable {
    case enlaceEnviado(correo: String)
}
