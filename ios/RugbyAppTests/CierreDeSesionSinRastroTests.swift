import XCTest
import Security
import Data
@testable import RugbyApp

/// SP-04 · H-1 (CP-155 / CA-4 / AT-10): cerrar sesión desde la app no deja NINGÚN ítem del Keychain de la app,
/// ni el de Supabase (`<bundle id>.sesion`) ni el que GoogleSignIn-iOS guarda con GTMAppAuth.
/// Sin un inicio real con Google, se simula el ítem de GoogleSignIn 9.0.0: `kSecClassGenericPassword`,
/// servicio "auth" (`kGTMAppAuthKeychainName`, GIDSignIn.m) y cuenta "OAuth" (GTMAppAuth KeychainWrapper).
@MainActor
final class CierreDeSesionSinRastroTests: XCTestCase {
    private let tokenDeGoogle = "rt-google-sp04-\(UUID().uuidString)"

    override func setUp() async throws {
        borrarTodosLosItemsDeLaApp()
    }

    override func tearDown() async throws {
        borrarTodosLosItemsDeLaApp()
    }

    func test_CP155_cerrarSesionNoDejaNingunItemDeLaAppEnElKeychain() async throws {
        try guardarItemComoGoogleSignIn()
        let bundleID = try XCTUnwrap(Bundle.main.bundleIdentifier)
        try AlmacenDeSesionKeychain(servicio: "\(bundleID).sesion")
            .store(key: "supabase.auth.token", value: Data(#"{"access_token":"at","refresh_token":"rt"}"#.utf8))
        XCTAssertEqual(itemsDeLaApp().count, 2, "precondición: sesión de Supabase + estado de GoogleSignIn")

        let viewModel = ContenedorDeDependencias().accesoViewModel
        await viewModel.cerrarSesion()

        XCTAssertEqual(viewModel.estado, .sinSesion)
        let restantes = itemsDeLaApp()
        XCTAssertTrue(restantes.isEmpty, "quedan ítems en el Keychain: \(restantes.map(Self.describir))")
    }

    // MARK: - Keychain

    private func guardarItemComoGoogleSignIn() throws {
        let item: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "auth",
            kSecAttrAccount as String: "OAuth",
            kSecUseDataProtectionKeychain as String: true,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: Data(tokenDeGoogle.utf8)
        ]
        let estado = SecItemAdd(item as CFDictionary, nil)
        XCTAssertEqual(estado, errSecSuccess, "no se pudo simular el ítem de GoogleSignIn")
    }

    /// Todos los `kSecClassGenericPassword` de la app, sin filtrar por servicio.
    private func itemsDeLaApp() -> [[String: Any]] {
        let consulta: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecUseDataProtectionKeychain as String: true,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        var resultado: AnyObject?
        let estado = SecItemCopyMatching(consulta as CFDictionary, &resultado)
        guard estado == errSecSuccess else { return [] }
        return (resultado as? [[String: Any]]) ?? []
    }

    private func borrarTodosLosItemsDeLaApp() {
        let consulta: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecUseDataProtectionKeychain as String: true
        ]
        SecItemDelete(consulta as CFDictionary)
    }

    private static func describir(_ item: [String: Any]) -> String {
        "\(item[kSecAttrService as String] ?? "?")/\(item[kSecAttrAccount as String] ?? "?")"
    }
}
