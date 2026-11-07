// C-01 · Aviso de Privacidad (RNF-10, LFPDPPP; domain-model.md §1). La versión vigente la fija Domain y la vuelve a
// exigir el servidor (privado.version_vigente_del_aviso()). Cambiar de versión = migración nueva + pedirlo otra vez.
// Espejo en Android: domain/.../cuentas/AvisoDePrivacidad.kt.

public enum AvisoDePrivacidad {
    public static let versionVigente = "v0-borrador"
}

/// Finalidades secundarias del aviso (§3). Opcionales, cada una con su casilla, desmarcadas por defecto (A-1).
/// Los valores crudos coinciden con el tipo `public.finalidad_secundaria` del backend.
public enum FinalidadSecundaria: String, CaseIterable, Sendable {
    case notificaciones
    case comunicaciones
    case estadisticas
}
