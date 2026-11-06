package mx.rugbyapp.domain.cuentas

/**
 * SP-04 · Puerto: abre el SDK nativo del proveedor (Google) y devuelve su credencial. Recibe el nonce YA HASHEADO
 * (SHA-256 en hex) y lo pasa tal cual al proveedor (CP-159). El adaptador vive en :app porque depende de la UI.
 */
interface ObtenedorDeCredencial {
    suspend fun obtener(p: ProveedorDeIdentidad, nonceHasheado: String): CredencialNativa
}
