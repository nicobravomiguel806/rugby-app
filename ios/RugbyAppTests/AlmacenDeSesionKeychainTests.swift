import XCTest
import Security
import Data

/// SP-04 · Almacén real (Keychain del simulador), alojado en RugbyApp. CP-154 (persiste en otra instancia),
/// CP-155 (cerrar sesión no deja token) y CA-1 (nada en UserDefaults ni en Library/Preferences).
/// Espejo en Android: app/src/androidTest/kotlin/mx/rugbyapp/app/AlmacenDeSesionCifradoTest.kt.
final class AlmacenDeSesionKeychainTests: XCTestCase {
    private let servicio = "mx.rugbyapp.pruebas.sesion.\(UUID().uuidString)"
    private let clave = "supabase.auth.token"
    private let accessToken = "at-secreto-sp04-\(UUID().uuidString)"
    private let refreshToken = "rt-secreto-sp04-\(UUID().uuidString)"
    private var sesionJSON: Data {
        Data(#"{"access_token":"\#(accessToken)","refresh_token":"\#(refreshToken)","token_type":"bearer"}"#.utf8)
    }

    override func tearDownWithError() throws {
        try AlmacenDeSesionKeychain(servicio: servicio).borrarTodo()
    }

    func test_CP154_guardaYOtraInstanciaLeeLaMismaSesion() throws {
        try AlmacenDeSesionKeychain(servicio: servicio).store(key: clave, value: sesionJSON)

        let otraInstancia = AlmacenDeSesionKeychain(servicio: servicio)

        XCTAssertEqual(try otraInstancia.retrieve(key: clave), sesionJSON)
        try assertSinTokensFueraDelKeychain()
    }

    func test_CP154_seGuardaSoloEnEsteDispositivo() throws {
        try AlmacenDeSesionKeychain(servicio: servicio).store(key: clave, value: sesionJSON)

        let consulta: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicio,
            kSecAttrAccount as String: clave,
            kSecUseDataProtectionKeychain as String: true,
            kSecReturnAttributes as String: true
        ]
        var resultado: AnyObject?
        XCTAssertEqual(SecItemCopyMatching(consulta as CFDictionary, &resultado), errSecSuccess)
        let atributos = try XCTUnwrap(resultado as? [String: Any])
        XCTAssertEqual(atributos[kSecAttrAccessible as String] as? String, kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
    }

    func test_CP155_borrarTodoNoDejaTokenEnElEquipo() throws {
        let almacen = AlmacenDeSesionKeychain(servicio: servicio)
        try almacen.store(key: clave, value: sesionJSON)
        try almacen.store(key: "\(clave)-code-verifier", value: Data("verificador".utf8))

        try almacen.borrarTodo()

        let otraInstancia = AlmacenDeSesionKeychain(servicio: servicio)
        XCTAssertNil(try otraInstancia.retrieve(key: clave))
        XCTAssertNil(try otraInstancia.retrieve(key: "\(clave)-code-verifier"))
        try assertSinTokensFueraDelKeychain()
    }

    /// CA-1: ni UserDefaults ni ningún .plist de Library/Preferences contienen los tokens.
    private func assertSinTokensFueraDelKeychain(file: StaticString = #filePath, line: UInt = #line) throws {
        UserDefaults.standard.synchronize()
        let defaults = String(describing: UserDefaults.standard.dictionaryRepresentation())
        for secreto in [accessToken, refreshToken] {
            XCTAssertFalse(defaults.contains(secreto), "UserDefaults contiene un token", file: file, line: line)
        }
        let preferencias = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Preferences")
        let archivos = (try? FileManager.default.contentsOfDirectory(at: preferencias, includingPropertiesForKeys: nil)) ?? []
        for archivo in archivos {
            let contenido = try Data(contentsOf: archivo)
            for secreto in [accessToken, refreshToken] {
                XCTAssertNil(contenido.range(of: Data(secreto.utf8)), "\(archivo.lastPathComponent) contiene un token", file: file, line: line)
            }
        }
    }
}
