package mx.rugbyapp.domain.cuentas

/**
 * C-01 · ¿El usuario de la sesión ya aceptó el aviso vigente? El servidor es la fuente de verdad: no hay estado local
 * de «pendiente» (CP-164d). Espejo en iOS: Domain/Cuentas/ConsultarAvisoAceptadoUseCase.swift.
 */
class ConsultarAvisoAceptadoUseCase(private val repositorio: RepositorioDeConsentimiento) {
    suspend fun ejecutar(): Boolean = repositorio.avisoAceptado(AvisoDePrivacidad.VERSION_VIGENTE)
}
