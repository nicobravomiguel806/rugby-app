// C-01 · H-6: al arrancar con una sesión guardada, ¿hay que pedir el aviso? (§3.6, CP-164d, CP-164e).
// Sin sesión, no. Si la consulta falla (sin red), no se bloquea: se vuelve a consultar en el siguiente arranque.
// Si llegó un enlace de verificación del correo (antes o durante la consulta), tampoco: el flujo del enlace confirma,
// registra lo marcado en el formulario y consulta el aviso después. Así la consulta del arranque, que puede caer
// entre el canje del enlace y el registro del aviso, no muestra el aviso a quien ya lo aceptó.
// Espejo en Android: domain/.../cuentas/HayQuePedirElAvisoAlArrancarUseCase.kt.

public struct HayQuePedirElAvisoAlArrancarUseCase: Sendable {
    private let obtenerSesionActual: ObtenerSesionActualUseCase
    private let consultar: ConsultarAvisoAceptadoUseCase

    public init(obtenerSesionActual: ObtenerSesionActualUseCase, consultar: ConsultarAvisoAceptadoUseCase) {
        self.obtenerSesionActual = obtenerSesionActual
        self.consultar = consultar
    }

    /// `llegoUnEnlace`: si en esta ejecución de la app ya llegó un enlace de verificación. Se pregunta antes y después
    /// de la consulta.
    public func ejecutar(llegoUnEnlace: @Sendable () async -> Bool) async -> Bool {
        if await llegoUnEnlace() { return false }
        guard await obtenerSesionActual.ejecutar() != nil else { return false }
        guard let aceptado = try? await consultar.ejecutar() else { return false }
        if await llegoUnEnlace() { return false }
        return !aceptado
    }
}
