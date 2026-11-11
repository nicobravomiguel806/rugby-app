// SP-04 · Inicio de sesión nativo con nonce obligatorio (P-9). Espejo en Android: domain/.../cuentas/IniciarSesionUseCase.kt.
//
// Contrato del nonce (CP-159): al proveedor (Google) se le pasa SHA-256(nonce) en hex y a Supabase el nonce crudo.
// Supabase hashea el crudo y lo compara con el claim `nonce` del ID token. Domain solo orquesta: no hace criptografía.
// C-02 · Antes de abrir Google reintenta las revocaciones pendientes; después de iniciar, las pendientes de la misma
// cuenta pierden el aviso y conservan solo la revocación de la sesión vieja (P-4, CP-165e).

public struct IniciarSesionUseCase: Sendable {
    private let generadorDeNonce: GeneradorDeNonce
    private let hashDeNonce: HashDeNonce
    private let obtenedor: ObtenedorDeCredencial
    private let repositorio: RepositorioDeSesion
    private let pendientes: RepositorioDeRevocacionesPendientes
    private let reintentar: ReintentarRevocacionesPendientesUseCase

    public init(
        generadorDeNonce: GeneradorDeNonce,
        hashDeNonce: HashDeNonce,
        obtenedor: ObtenedorDeCredencial,
        repositorio: RepositorioDeSesion,
        pendientes: RepositorioDeRevocacionesPendientes,
        reintentar: ReintentarRevocacionesPendientesUseCase
    ) {
        self.generadorDeNonce = generadorDeNonce
        self.hashDeNonce = hashDeNonce
        self.obtenedor = obtenedor
        self.repositorio = repositorio
        self.pendientes = pendientes
        self.reintentar = reintentar
    }

    public func ejecutar(_ proveedor: ProveedorDeIdentidad) async throws -> Sesion {
        let nonceCrudo = generadorDeNonce.generar()
        guard !nonceCrudo.isEmpty else { throw ErrorDeAutenticacion.credencialRechazada }
        let nonceHasheado = hashDeNonce.sha256Hex(nonceCrudo)

        await reintentar.ejecutar()
        let credencial = try await obtenedor.obtener(proveedor, nonceHasheado: nonceHasheado) // a Google, el HASH
        let sesion = try await repositorio.iniciarSesion(con: credencial, nonce: nonceCrudo)  // a Supabase, el CRUDO
        try? await pendientes.quitarAviso(usuarioId: sesion.usuarioId)
        return sesion
    }
}
