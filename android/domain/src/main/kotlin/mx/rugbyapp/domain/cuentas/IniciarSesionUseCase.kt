package mx.rugbyapp.domain.cuentas

/**
 * SP-04 · Inicio de sesión nativo con nonce obligatorio (P-9). Espejo en iOS: Domain/Cuentas/IniciarSesionUseCase.swift.
 *
 * Contrato del nonce (CP-159): al proveedor (Google) se le pasa SHA-256(nonce) en hex y a Supabase el nonce crudo.
 * Supabase hashea el crudo y lo compara con el claim `nonce` del ID token. Domain solo orquesta: no hace criptografía.
 */
class IniciarSesionUseCase(
    private val generadorDeNonce: GeneradorDeNonce,
    private val hashDeNonce: HashDeNonce,
    private val obtenedor: ObtenedorDeCredencial,
    private val repositorio: RepositorioDeSesion,
) {
    suspend fun ejecutar(p: ProveedorDeIdentidad): Sesion {
        val nonceCrudo = generadorDeNonce.generar()
        if (nonceCrudo.isEmpty()) throw ErrorDeAutenticacion.CredencialRechazada
        val nonceHasheado = hashDeNonce.sha256Hex(nonceCrudo)

        val credencial = obtenedor.obtener(p, nonceHasheado = nonceHasheado) // a Google, el HASH
        return repositorio.iniciarSesion(credencial, nonce = nonceCrudo)     // a Supabase, el CRUDO
    }
}
