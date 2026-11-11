package mx.rugbyapp.domain.cuentas

/**
 * C-02 · D-5: inicio de sesión con correo y contraseña (domain-model.md §1). El correo se normaliza y se valida; la
 * contraseña no puede estar vacía y no tiene regla de longitud (la decide el servidor). Antes de iniciar reintenta las
 * revocaciones pendientes; después, las de la misma cuenta pierden el aviso (P-4, CP-165d/e).
 * Espejo en iOS: Domain/Cuentas/IniciarSesionConCorreoUseCase.swift.
 */
class IniciarSesionConCorreoUseCase(
    private val repositorio: RepositorioDeSesion,
    private val pendientes: RepositorioDeRevocacionesPendientes,
    private val reintentar: ReintentarRevocacionesPendientesUseCase,
) {
    suspend fun ejecutar(credenciales: CredencialesDeCorreo): Sesion {
        val correo = ValidadorDeRegistro.normalizarCorreo(credenciales.correo)
        if (!ValidadorDeRegistro.esCorreoValido(correo)) throw ErrorDeAutenticacion.CorreoInvalido
        if (credenciales.contrasena.isEmpty()) throw ErrorDeAutenticacion.CredencialRechazada

        reintentar.ejecutar()
        val sesion = repositorio.iniciarSesion(correo, credenciales.contrasena)
        ignorarFallas { pendientes.quitarAviso(sesion.usuarioId) }
        return sesion
    }
}
