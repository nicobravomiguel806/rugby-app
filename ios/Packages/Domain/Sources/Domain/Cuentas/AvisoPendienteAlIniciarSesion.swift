// C-02 · R-1 (CA-7, P-4; ADR 0010, domain-model.md §1): tras iniciar sesión, si alguna revocación pendiente de esa
// cuenta todavía debía revocar el aviso, lo revoca en línea con la sesión nueva (la RPC es idempotente) ANTES de quitarlo
// de la pendiente. Así el «No acepto» no se pierde aunque el reintento previo haya fallado o la sesión vieja ya no valga,
// y la App, que consulta el aviso después, lo vuelve a pedir. Ocurre antes de que se pueda aceptar el aviso con la sesión
// nueva, así que nunca revoca una aceptación posterior hecha en este dispositivo. Si la revocación falla y el aviso sigue
// aceptado (o no se sabe), la pendiente lo conserva. Nunca lanza: el inicio de sesión no falla por esto.
// Lo usan IniciarSesionUseCase e IniciarSesionConCorreoUseCase. Espejo en Android: domain/.../cuentas/AvisoPendienteAlIniciarSesion.kt.

struct AvisoPendienteAlIniciarSesion: Sendable {
    let pendientes: RepositorioDeRevocacionesPendientes
    let consentimiento: RepositorioDeConsentimiento

    func resolver(usuarioId: String) async {
        var versiones: [String] = []
        for pendiente in await pendientes.pendientes() where pendiente.usuarioId == usuarioId {
            if let version = pendiente.versionDelAvisoPorRevocar, !versiones.contains(version) { versiones.append(version) }
        }
        var resuelto = true
        for version in versiones {
            do {
                try await consentimiento.revocarAviso(version: version)
            } catch {
                // ¿Se revocó igual (respuesta perdida) o no estaba aceptado? Si sigue aceptado o no se sabe, se conserva.
                if (try? await consentimiento.avisoAceptado(version: version)) != false { resuelto = false }
            }
        }
        if resuelto { try? await pendientes.quitarAviso(usuarioId: usuarioId) }
    }
}
