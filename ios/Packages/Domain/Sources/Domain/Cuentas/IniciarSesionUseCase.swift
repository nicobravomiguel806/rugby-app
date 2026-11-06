// SP-04 · Inicio de sesión nativo con nonce obligatorio (P-9). Espejo en Android: domain/.../cuentas/IniciarSesionUseCase.kt.
//
// Contrato del nonce (CP-159): al proveedor (Google) se le pasa SHA-256(nonce) en hex y a Supabase el nonce crudo.
// Supabase hashea el crudo y lo compara con el claim `nonce` del ID token. Domain solo orquesta: no hace criptografía.

public struct IniciarSesionUseCase: Sendable {
    private let generadorDeNonce: GeneradorDeNonce
    private let hashDeNonce: HashDeNonce
    private let obtenedor: ObtenedorDeCredencial
    private let repositorio: RepositorioDeSesion

    public init(
        generadorDeNonce: GeneradorDeNonce,
        hashDeNonce: HashDeNonce,
        obtenedor: ObtenedorDeCredencial,
        repositorio: RepositorioDeSesion
    ) {
        self.generadorDeNonce = generadorDeNonce
        self.hashDeNonce = hashDeNonce
        self.obtenedor = obtenedor
        self.repositorio = repositorio
    }

    public func ejecutar(_ proveedor: ProveedorDeIdentidad) async throws -> Sesion {
        let nonceCrudo = generadorDeNonce.generar()
        guard !nonceCrudo.isEmpty else { throw ErrorDeAutenticacion.credencialRechazada }
        let nonceHasheado = hashDeNonce.sha256Hex(nonceCrudo)

        let credencial = try await obtenedor.obtener(proveedor, nonceHasheado: nonceHasheado) // a Google, el HASH
        return try await repositorio.iniciarSesion(con: credencial, nonce: nonceCrudo)          // a Supabase, el CRUDO
    }
}
