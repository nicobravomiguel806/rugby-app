import UIKit
import GoogleSignIn
import Domain

/// SP-04 · Adaptador de Google para el puerto ObtenedorDeCredencial (ADR 0006). Vive en App porque necesita la UI.
/// Recibe `nonceHasheado` (SHA-256 en hex) del caso de uso y lo pasa TAL CUAL a GoogleSignIn: no genera ni hashea nada
/// (CP-159). Google lo copia al claim `nonce` del ID token. Espejo en Android: app/.../cuentas/ObtenedorDeCredencialGoogle.kt.
final class ObtenedorDeCredencialGoogle: ObtenedorDeCredencial {
    private let clientID: String
    private let serverClientID: String
    private let esquemaDeURL: String

    /// `clientID`: cliente iOS · `serverClientID`: cliente Web (el que Supabase valida) · `esquemaDeURL`: client id iOS invertido.
    init(clientID: String, serverClientID: String, esquemaDeURL: String) {
        self.clientID = clientID
        self.serverClientID = serverClientID
        self.esquemaDeURL = esquemaDeURL
    }

    func obtener(_ proveedor: ProveedorDeIdentidad, nonceHasheado: String) async throws -> CredencialNativa {
        // Apple no tiene adaptador hasta SP-07. Sin llaves, GoogleSignIn lanza una excepción de Objective-C: se evita aquí.
        guard proveedor == .google, !clientID.isEmpty, !serverClientID.isEmpty,
              esquemaDeURL.hasPrefix("com.googleusercontent.apps.") else {
            throw ErrorDeAutenticacion.configuracionIncompleta
        }
        return try await iniciarConGoogle(nonceHasheado: nonceHasheado)
    }

    @MainActor
    private func iniciarConGoogle(nonceHasheado: String) async throws -> CredencialNativa {
        guard let presentador = Self.controladorVisible() else { throw ErrorDeAutenticacion.desconocido }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID, serverClientID: serverClientID)
        do {
            let resultado = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: presentador, hint: nil, additionalScopes: nil, nonce: nonceHasheado
            )
            let idToken = resultado.user.idToken?.tokenString
            let accessToken = resultado.user.accessToken.tokenString
            // H-1 (AT-10): tras el intercambio no se necesita la sesión de Google; se borra ya de su Keychain.
            GIDSignIn.sharedInstance.signOut()
            guard let idToken else { throw ErrorDeAutenticacion.credencialRechazada }
            return CredencialNativa(proveedor: .google, idToken: idToken, accessToken: accessToken)
        } catch let error as GIDSignInError where error.code == .canceled {
            throw ErrorDeAutenticacion.cancelado
        } catch let error as ErrorDeAutenticacion {
            throw error
        } catch let error as URLError {
            throw error.code == .notConnectedToInternet ? ErrorDeAutenticacion.sinConexion : ErrorDeAutenticacion.desconocido
        } catch {
            throw ErrorDeAutenticacion.desconocido
        }
    }

    /// El controlador de más arriba: la pantalla Acceso se abre como hoja sobre Inicio.
    @MainActor
    private static func controladorVisible() -> UIViewController? {
        let escenas = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let escena = escenas.first { $0.activationState == .foregroundActive } ?? escenas.first
        var controlador = escena?.windows.first { $0.isKeyWindow }?.rootViewController ?? escena?.windows.first?.rootViewController
        while let presentado = controlador?.presentedViewController { controlador = presentado }
        return controlador
    }
}
