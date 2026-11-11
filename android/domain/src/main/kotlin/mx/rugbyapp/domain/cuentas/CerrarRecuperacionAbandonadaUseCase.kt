package mx.rugbyapp.domain.cuentas

/**
 * C-02 · D-7 (P-7): si la persona abandona Nueva contraseña (Cancelar, atrás o cerrar la app), se cierra la sesión de
 * recuperación y se quita la marca. Corre también al arrancar, antes de cualquier otra acción (CP-166e, C02-11).
 * Espejo en iOS: Domain/Cuentas/CerrarRecuperacionAbandonadaUseCase.swift.
 */
class CerrarRecuperacionAbandonadaUseCase(
    private val repositorio: RepositorioDeRecuperacion,
    private val cerrarSesion: CerrarSesionUseCase,
) {
    suspend fun ejecutar() {
        if (!repositorio.recuperacionEnCurso()) return
        cerrarSesion.ejecutar()
        repositorio.terminarRecuperacion()
    }
}
