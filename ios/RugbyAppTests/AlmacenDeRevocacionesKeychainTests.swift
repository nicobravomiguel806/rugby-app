import XCTest
import Security
import Data

/// C-02 · CP-167h (ADR 0010, AT-10, AT-17): la revocación pendiente vive en el Keychain real, con
/// `AfterFirstUnlockThisDeviceOnly`, en otro servicio que la sesión: cerrar sesión (`borrarTodo()` de la sesión) no la
/// borra, y nada queda en UserDefaults. Espejo en Android: app/src/androidTest/.../AlmacenDeSesionCifradoTest.kt (CP-167h).
final class AlmacenDeRevocacionesKeychainTests: XCTestCase {
    private let base = "mx.rugbyapp.pruebas.\(UUID().uuidString)"
    private let refreshToken = "rt-secreto-c02-\(UUID().uuidString)"
    private var servicioDeRevocaciones: String { "\(base).revocaciones" }
    private var servicioDeSesion: String { "\(base).sesion" }

    override func tearDownWithError() throws {
        let revocaciones = AlmacenDeRevocacionesKeychain(servicio: servicioDeRevocaciones)
        for id in try revocaciones.ids() { try revocaciones.borrar(id: id) }
        try AlmacenDeSesionKeychain(servicio: servicioDeSesion).borrarTodo()
    }

    private var entrada: Data { Data(#"{"usuarioId":"u-1","refreshToken":"\#(refreshToken)","creadaEn":1}"#.utf8) }

    func test_CP167h_laPendienteSeGuardaSoloEnEsteDispositivoYSeListaPorId() throws {
        let almacen = AlmacenDeRevocacionesKeychain(servicio: servicioDeRevocaciones)

        try almacen.guardar(entrada, id: "p-1")
        try almacen.guardar(entrada, id: "p-2")

        XCTAssertEqual(try AlmacenDeRevocacionesKeychain(servicio: servicioDeRevocaciones).ids().sorted(), ["p-1", "p-2"])
        XCTAssertEqual(try almacen.leer(id: "p-1"), entrada)
        XCTAssertEqual(try almacen.accesibilidad(id: "p-1"), kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
        try almacen.borrar(id: "p-1")
        XCTAssertEqual(try almacen.ids(), ["p-2"])
    }

    func test_CP167h_cerrarSesionNoBorraLaPendiente() throws {
        let revocaciones = AlmacenDeRevocacionesKeychain(servicio: servicioDeRevocaciones)
        let sesion = AlmacenDeSesionKeychain(servicio: servicioDeSesion)
        try revocaciones.guardar(entrada, id: "p-1")
        try sesion.store(key: "supabase.auth.token", value: Data("sesion".utf8))

        try sesion.borrarTodo()

        XCTAssertNil(try sesion.retrieve(key: "supabase.auth.token"))
        XCTAssertEqual(try revocaciones.ids(), ["p-1"], "la pendiente queda (excepción aprobada a CA-3, P-3)")
    }

    func test_CP167h_C02_6_nadaEnUserDefaults() throws {
        try AlmacenDeRevocacionesKeychain(servicio: servicioDeRevocaciones).guardar(entrada, id: "p-1")

        let enDefaults = UserDefaults.standard.dictionaryRepresentation().values.contains { "\($0)".contains(refreshToken) }
        XCTAssertFalse(enDefaults)
    }
}
