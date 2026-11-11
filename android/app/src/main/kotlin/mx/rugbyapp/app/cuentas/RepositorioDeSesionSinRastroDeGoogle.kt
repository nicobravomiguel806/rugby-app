package mx.rugbyapp.app.cuentas

import kotlin.coroutines.cancellation.CancellationException
import mx.rugbyapp.domain.cuentas.CredencialNativa
import mx.rugbyapp.domain.cuentas.RepositorioDeSesion
import mx.rugbyapp.domain.cuentas.Sesion

/**
 * C-02 · CA-3 (SP-04 H-3): al cerrar sesión también se limpia el estado de Credential Manager, para que el siguiente
 * «Continuar con Google» no reuse en silencio la cuenta anterior. Decorador del puerto, como
 * RepositorioDeSesionSinRastroDeGoogle.swift en iOS. Es local: si falla, el cierre sigue (P-8).
 */
class RepositorioDeSesionSinRastroDeGoogle(
    private val interno: RepositorioDeSesion,
    private val google: ObtenedorDeCredencialGoogle,
) : RepositorioDeSesion {
    override suspend fun iniciarSesion(c: CredencialNativa, nonce: String): Sesion = interno.iniciarSesion(c, nonce)

    override suspend fun iniciarSesion(correo: String, contrasena: String): Sesion = interno.iniciarSesion(correo, contrasena)

    override suspend fun sesionActual(): Sesion? = interno.sesionActual()

    override suspend fun borrarSesionLocal() {
        try {
            google.olvidarCredencial()
        } catch (e: CancellationException) {
            throw e
        } catch (_: Exception) {
            // Sin Credential Manager disponible no hay nada que limpiar.
        }
        interno.borrarSesionLocal()
    }
}
