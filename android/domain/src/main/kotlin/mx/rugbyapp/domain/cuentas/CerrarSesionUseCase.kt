package mx.rugbyapp.domain.cuentas

import kotlin.coroutines.cancellation.CancellationException

/**
 * SP-04 · Regla de domain-model.md §1 (P-8): cerrar sesión cierra solo este dispositivo. Primero borra siempre la
 * sesión local, aunque no haya red, y después intenta revocarla; si la revocación falla, el cierre local se mantiene
 * (CP-155). Espejo en iOS: Domain/Cuentas/CerrarSesionUseCase.swift.
 */
class CerrarSesionUseCase(private val repositorio: RepositorioDeSesion) {
    suspend fun ejecutar() {
        repositorio.borrarSesionLocal()
        try {
            repositorio.revocarSesionEnServidor()
        } catch (e: CancellationException) {
            throw e
        } catch (_: Exception) {
            // Se descarta: el cierre local ya ocurrió (P-8).
        }
    }
}
