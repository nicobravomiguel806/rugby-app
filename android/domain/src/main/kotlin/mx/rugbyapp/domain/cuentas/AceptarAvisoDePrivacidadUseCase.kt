package mx.rugbyapp.domain.cuentas

/**
 * C-01 · CA-4: aceptar el aviso vigente con las finalidades marcadas, una por una (A-1). El llamador no elige la versión.
 * Espejo en iOS: Domain/Cuentas/AceptarAvisoDePrivacidadUseCase.swift.
 */
class AceptarAvisoDePrivacidadUseCase(private val repositorio: RepositorioDeConsentimiento) {
    suspend fun ejecutar(finalidades: Set<FinalidadSecundaria>) {
        repositorio.aceptarAviso(AvisoDePrivacidad.VERSION_VIGENTE, finalidades)
    }
}
