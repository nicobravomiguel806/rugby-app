import GoogleSignIn
import Domain

/// SP-04 · H-1 (CP-155 / AT-10): GoogleSignIn-iOS guarda en el Keychain su propio estado (refresh, access e ID token
/// de Google, ítem "auth" de GTMAppAuth). Este decorador del puerto RepositorioDeSesion lo borra al cerrar sesión,
/// además de la sesión de Supabase. Vive en App porque es el único que conoce GoogleSignIn (Data y Domain no).
/// `signOut()` es local (no usa la red), así que se cumple P-8 aunque no haya conexión.
/// Espejo conceptual en Android: Credential Manager no deja tokens en la app (ver H-3).
final class RepositorioDeSesionSinRastroDeGoogle: RepositorioDeSesion {
    private let interno: RepositorioDeSesion

    init(_ interno: RepositorioDeSesion) {
        self.interno = interno
    }

    func iniciarSesion(con credencial: CredencialNativa, nonce: String) async throws -> Sesion {
        try await interno.iniciarSesion(con: credencial, nonce: nonce)
    }

    func sesionActual() async -> Sesion? {
        await interno.sesionActual()
    }

    func borrarSesionLocal() async throws {
        await MainActor.run { GIDSignIn.sharedInstance.signOut() }
        try await interno.borrarSesionLocal()
    }

    func revocarSesionEnServidor() async throws {
        try await interno.revocarSesionEnServidor()
    }
}
