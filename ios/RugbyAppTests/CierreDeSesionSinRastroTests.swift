import XCTest
import Security
import Data
@testable import RugbyApp

/// SP-04 · H-1 (CP-155 / CA-4 / AT-10): cerrar sesión desde la app no deja NINGÚN ítem del Keychain de la app,
/// ni el de Supabase (`<bundle id>.sesion`) ni el que GoogleSignIn-iOS guarda con GTMAppAuth.
/// Sin un inicio real con Google, se simula el ítem de GoogleSignIn 9.0.0: `kSecClassGenericPassword`,
/// servicio "auth" (`kGTMAppAuthKeychainName`, GIDSignIn.m) y cuenta "OAuth" (GTMAppAuth KeychainWrapper).
/// C-02 · CP-167h (ADR 0011, cierra H-6): con una sesión de Supabase real (que se decodifica) y sin red, cerrar sesión
/// tampoco deja nada: ni la sesión ni una entrada `<bundle id>.revocaciones`.
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

    func test_CP167h_cerrarSesionSinRedConUnaSesionRealNoDejaNadaNiRevocacionesEnElKeychain() async throws {
        let bundleID = try XCTUnwrap(Bundle.main.bundleIdentifier)
        try AlmacenDeSesionKeychain(servicio: "\(bundleID).sesion").store(key: "supabase.auth.token", value: Self.sesionReal)
        // Sin red: el puerto 1 de localhost rechaza la conexión, así que el logout en el servidor falla.
        let contenedor = ContenedorDeDependencias(info: ["SupabaseURL": "https://127.0.0.1:1", "SupabaseAnonKey": "anon-de-prueba"],
                                                  bundleID: bundleID)
        let antes = await contenedor.obtenerSesionActual.ejecutar()
        XCTAssertEqual(antes?.usuarioId, "8f2c0a4e-1b2d-4c3e-9f00-123456789abc", "precondición: la sesión se decodifica")

        await contenedor.accesoViewModel.cerrarSesion()

        XCTAssertEqual(contenedor.accesoViewModel.estado, .sinSesion, "sin red el cierre es solo local y no falla")
        let restantes = itemsDeLaApp()
        XCTAssertTrue(restantes.isEmpty, "quedan ítems en el Keychain: \(restantes.map(Self.describir))")
        XCTAssertFalse(restantes.contains { ($0[kSecAttrService as String] as? String) == "\(bundleID).revocaciones" })
    }

    /// Una sesión con el formato que guarda supabase-swift, vigente hasta 2100 (no intenta renovarla al arrancar).
    private static let sesionReal = Data("""
    {"access_token":"at-123","token_type":"bearer","expires_in":3600,"expires_at":4102444800,"refresh_token":"rt-123",
     "user":{"id":"8F2C0A4E-1B2D-4C3E-9F00-123456789ABC","aud":"authenticated","email":"jugador@rugby.mx",
             "app_metadata":{},"user_metadata":{},"is_anonymous":false,
             "created_at":"2026-11-05T00:00:00Z","updated_at":"2026-11-05T00:00:00Z"}}
    """.utf8)

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
