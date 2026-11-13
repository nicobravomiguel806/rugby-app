package mx.rugbyapp.domain.cuentas

/**
 * C-01 · Aviso de Privacidad (RNF-10, LFPDPPP; domain-model.md §1). La versión vigente la fija Domain y la vuelve a
 * exigir el servidor (privado.version_vigente_del_aviso()). Cambiar de versión = migración nueva + pedirlo otra vez.
 * Espejo en iOS: Domain/Cuentas/AvisoDePrivacidad.swift.
 */
object AvisoDePrivacidad {
    const val VERSION_VIGENTE = "v0-borrador"
}

/**
 * Finalidades secundarias del aviso (§3). Opcionales, cada una con su casilla, desmarcadas por defecto (A-1).
 * `valorCrudo` coincide con el tipo `public.finalidad_secundaria` del backend.
 */
enum class FinalidadSecundaria(val valorCrudo: String) {
    NOTIFICACIONES("notificaciones"),
    COMUNICACIONES("comunicaciones"),
    ESTADISTICAS("estadisticas"),
}
