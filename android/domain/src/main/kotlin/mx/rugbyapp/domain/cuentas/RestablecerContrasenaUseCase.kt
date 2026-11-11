package mx.rugbyapp.domain.cuentas

/**
 * C-02 · CA-2, D-7: la nueva contraseña sigue la regla del registro (10 caracteres o más, sin composición). Se cambia,
 * se cierran las sesiones en los demás dispositivos y se quita la marca «en curso», en ese orden (CP-166c).
 * Espejo en iOS: Domain/Cuentas/RestablecerContrasenaUseCase.swift.
 */
class RestablecerContrasenaUseCase(private val repositorio: RepositorioDeRecuperacion) {
    suspend fun ejecutar(nueva: String) {
        if (nueva.codePointCount(0, nueva.length) < ValidadorDeRegistro.LONGITUD_MINIMA_DE_LA_CONTRASENA) {
            throw ErrorDeRecuperacion.ContrasenaCorta
        }
        repositorio.cambiarContrasena(nueva)
        repositorio.cerrarOtrasSesiones()
        repositorio.terminarRecuperacion()
    }
}
