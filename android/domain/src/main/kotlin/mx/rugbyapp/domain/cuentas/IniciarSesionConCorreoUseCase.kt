package mx.rugbyapp.domain.cuentas

/**
 * C-02 · D-5: inicio de sesión con correo y contraseña (domain-model.md §1). El correo se normaliza y se valida; la
 * contraseña no puede estar vacía y no tiene regla de longitud (la decide el servidor). Antes de iniciar reintenta las
 * revocaciones pendientes; después, las de la misma cuenta pierden el aviso (P-4, CP-165d/e), pero antes ese aviso se
 * revoca con la sesión nueva para que el «No acepto» no se pierda (R-1, CP-165e/g/h).
 * Espejo en iOS: Domain/Cuentas/IniciarSesionConCorreoUseCase.swift.
 */
class IniciarSesionConCorreoUseCase(
    private val repositorio: RepositorioDeSesion,
    private val pendientes: RepositorioDeRevocacionesPendientes,
    private val reintentar: ReintentarRevocacionesPendientesUseCase,
    private val consentimiento: RepositorioDeConsentimiento,
) {
    suspend fun ejecutar(credenciales: CredencialesDeCorreo): Sesion {
        val correo = ValidadorDeRegistro.normalizarCorreo(credenciales.correo)
        if (!ValidadorDeRegistro.esCorreoValido(correo)) throw ErrorDeAutenticacion.CorreoInvalido
        if (credenciales.contrasena.isEmpty()) throw ErrorDeAutenticacion.CredencialRechazada

        reintentar.ejecutar()
        val sesion = repositorio.iniciarSesion(correo, credenciales.contrasena)
        AvisoPendienteAlIniciarSesion(pendientes, consentimiento).resolver(sesion.usuarioId)
        return sesion
    }
}
