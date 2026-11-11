// C-02 · Una revocación de sesión (y, si aplica, del aviso) que quedó pendiente en el dispositivo (ADR 0010).
// No lleva tokens: el refresh token cifrado vive solo en Data. Espejo en Android: domain/.../cuentas/RevocacionPendiente.kt.

public struct RevocacionPendiente: Equatable, Sendable {
    /// Pasados 7 días desde el alta, la pendiente se descarta sin usar el token (P-3, CP-167g).
    public static let vigenciaEnSegundos: Int64 = 7 * 86_400

    public let id: String
    public let usuarioId: String
    /// Versión del aviso de privacidad que hay que revocar antes de la sesión, o `nil` (CA-7).
    public let versionDelAvisoPorRevocar: String?
    public let creadaEnSegundos: Int64

    public init(id: String, usuarioId: String, versionDelAvisoPorRevocar: String?, creadaEnSegundos: Int64) {
        self.id = id
        self.usuarioId = usuarioId
        self.versionDelAvisoPorRevocar = versionDelAvisoPorRevocar
        self.creadaEnSegundos = creadaEnSegundos
    }
}

/// Cuántas pendientes se revocaron, cuántas vencieron (descartadas sin usar el token) y cuántas siguen pendientes.
public struct ResultadoDeReintento: Equatable, Sendable {
    public let revocadas: Int
    public let vencidas: Int
    public let pendientes: Int

    public init(revocadas: Int, vencidas: Int, pendientes: Int) {
        self.revocadas = revocadas
        self.vencidas = vencidas
        self.pendientes = pendientes
    }
}
