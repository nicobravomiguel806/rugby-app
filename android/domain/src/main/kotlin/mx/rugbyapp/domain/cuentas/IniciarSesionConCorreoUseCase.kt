package mx.rugbyapp.domain.cuentas

/**
 * C-02 · D-5: inicio de sesión con correo y contraseña (domain-model.md §1). El correo se normaliza y se valida; la
 * contraseña no puede estar vacía y no tiene regla de longitud (la decide el servidor). Solo inicia sesión: no revoca
 * ni consulta el aviso (ADR 0011, CP-165d). Espejo en iOS: Domain/Cuentas/IniciarSesionConCorreoUseCase.swift.
 */
class IniciarSesionConCorreoUseCase(private val repositorio: RepositorioDeSesion) {
    suspend fun ejecutar(credenciales: CredencialesDeCorreo): Sesion {
        val correo = ValidadorDeRegistro.normalizarCorreo(credenciales.correo)
        if (!ValidadorDeRegistro.esCorreoValido(correo)) throw ErrorDeAutenticacion.CorreoInvalido
        if (credenciales.contrasena.isEmpty()) throw ErrorDeAutenticacion.CredencialRechazada

        return repositorio.iniciarSesion(correo, credenciales.contrasena)
    }
}
