package mx.rugbyapp.domain.cuentas

import kotlin.coroutines.cancellation.CancellationException

/**
 * C-02 · R-1 (CA-7, P-4; ADR 0010, domain-model.md §1): tras iniciar sesión, si alguna revocación pendiente de esa
 * cuenta todavía debía revocar el aviso, lo revoca en línea con la sesión nueva (la RPC es idempotente) ANTES de quitarlo
 * de la pendiente. Así el «No acepto» no se pierde aunque el reintento previo haya fallado o la sesión vieja ya no valga,
 * y la App, que consulta el aviso después, lo vuelve a pedir. Ocurre antes de que se pueda aceptar el aviso con la sesión
 * nueva, así que nunca revoca una aceptación posterior hecha en este dispositivo. Si la revocación falla y el aviso sigue
 * aceptado (o no se sabe), la pendiente lo conserva. Nunca lanza: el inicio de sesión no falla por esto.
 * Lo usan IniciarSesionUseCase e IniciarSesionConCorreoUseCase. Espejo en iOS: Domain/Cuentas/AvisoPendienteAlIniciarSesion.swift.
 */
internal class AvisoPendienteAlIniciarSesion(
    private val pendientes: RepositorioDeRevocacionesPendientes,
    private val consentimiento: RepositorioDeConsentimiento,
) {
    suspend fun resolver(usuarioId: String) {
        val versiones = pendientes.pendientes()
            .filter { it.usuarioId == usuarioId }
            .mapNotNull { it.versionDelAvisoPorRevocar }
            .distinct()
        var resuelto = true
        for (version in versiones) {
            if (ignorarFallas { consentimiento.revocarAviso(version) }) continue
            // ¿Se revocó igual (respuesta perdida) o no estaba aceptado? Si sigue aceptado o no se sabe, se conserva.
            val aceptado = try {
                consentimiento.avisoAceptado(version)
            } catch (e: CancellationException) {
                throw e
            } catch (_: Exception) {
                null
            }
            if (aceptado != false) resuelto = false
        }
        if (resuelto) ignorarFallas { pendientes.quitarAviso(usuarioId) }
    }
}
