package mx.rugbyapp.domain.cuentas

import kotlin.coroutines.cancellation.CancellationException

/**
 * C-01 · CA-9 (A-2): «No acepto» cierra la sesión del dispositivo y no guarda nada más (domain-model.md §1).
 * H-6: si ya había un consentimiento guardado de la versión vigente, antes de cerrar la sesión registra la revocación
 * como registro nuevo (los consentimientos no se editan). Sin consentimiento previo no guarda nada (CP-164a).
 * La sesión local se cierra siempre, también si la consulta o la revocación fallan (CP-164g): en ese caso, ya con la
 * sesión cerrada, se propaga el error de consentimiento sin transformarse. Un error al borrar la sesión local se
 * propaga sin transformarse y tiene prioridad (CP-164c). Espejo en iOS: Domain/Cuentas/RechazarAvisoDePrivacidadUseCase.swift.
 */
class RechazarAvisoDePrivacidadUseCase(
    private val repositorio: RepositorioDeConsentimiento,
    private val cerrarSesion: CerrarSesionUseCase,
) {
    suspend fun ejecutar() {
        val errorAlRevocar: Exception? = try {
            // Con la sesión todavía abierta: el servidor registra la revocación a nombre de auth.uid().
            if (repositorio.avisoAceptado(AvisoDePrivacidad.VERSION_VIGENTE)) {
                repositorio.revocarAviso(AvisoDePrivacidad.VERSION_VIGENTE)
            }
            null
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            e
        }
        cerrarSesion.ejecutar()
        errorAlRevocar?.let { throw it }
    }
}
