// C-02 · CA-2, D-7: la nueva contraseña sigue la regla del registro (10 caracteres o más, sin composición). Se cambia,
// se cierran las sesiones en los demás dispositivos y se quita la marca «en curso», en ese orden (CP-166c).
// Espejo en Android: domain/.../cuentas/RestablecerContrasenaUseCase.kt.

public struct RestablecerContrasenaUseCase: Sendable {
    private let repositorio: RepositorioDeRecuperacion

    public init(repositorio: RepositorioDeRecuperacion) {
        self.repositorio = repositorio
    }

    public func ejecutar(nueva: String) async throws {
        guard nueva.unicodeScalars.count >= ValidadorDeRegistro.longitudMinimaDeLaContrasena else {
            throw ErrorDeRecuperacion.contrasenaCorta
        }
        try await repositorio.cambiarContrasena(nueva: nueva)
        try await repositorio.cerrarOtrasSesiones()
        try await repositorio.terminarRecuperacion()
    }
}
