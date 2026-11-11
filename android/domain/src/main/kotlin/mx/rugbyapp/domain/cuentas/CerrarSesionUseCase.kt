package mx.rugbyapp.domain.cuentas

/**
 * SP-04 · Regla de domain-model.md §1: cerrar sesión cierra solo este dispositivo. Primero borra siempre la sesión
 * local, aunque no haya red, y después intenta revocarla (CP-155).
 * C-02 · CA-3, CA-4 (ADR 0010): antes de borrar, guarda la revocación pendiente (refresh token cifrado en el almacén
 * seguro, solo para revocar). Si el borrado local falla, descarta la pendiente y propaga el error sin transformarse.
 * Después reintenta las pendientes; la red nunca lo hace fallar (CP-167).
 * Espejo en iOS: Domain/Cuentas/CerrarSesionUseCase.swift.
 */
class CerrarSesionUseCase(
    private val repositorio: RepositorioDeSesion,
    private val pendientes: RepositorioDeRevocacionesPendientes,
    private val reintentar: ReintentarRevocacionesPendientesUseCase,
) {
    /** `revocarAviso`: versión del aviso que también hay que revocar en el servidor (CA-7), o `null`. */
    suspend fun ejecutar(revocarAviso: String? = null) {
        var guardada: RevocacionPendiente? = null
        repositorio.sesionActual()?.let { sesion ->
            ignorarFallas { guardada = pendientes.guardar(sesion.usuarioId, revocarAviso) }
        }
        try {
            repositorio.borrarSesionLocal()
        } catch (e: Exception) {
            guardada?.let { p -> ignorarFallas { pendientes.descartar(p.id) } }
            throw e
        }
        reintentar.ejecutar()
    }
}
