import XCTest
@testable import Domain

/// SP-04 · CP-158 (inicio con Google, con fakes) y CP-159 (contrato del nonce).
/// Mismos casos que android/domain/src/test/.../cuentas/IniciarSesionUseCaseTest.kt.
final class IniciarSesionUseCaseTests: XCTestCase {
    private let credencial = CredencialNativa(proveedor: .google, idToken: "id-token", accessToken: "access-token")
    private var bitacora: Bitacora!
    private var repositorio: RepositorioFalso!

    override func setUp() {
        bitacora = Bitacora()
        repositorio = RepositorioFalso(bitacora: bitacora)
    }

    private func casoDeUso(
        nonce: String = "crudo-123",
        obtenedor: Result<CredencialNativa, ErrorDeAutenticacion>? = nil
    ) -> IniciarSesionUseCase {
        IniciarSesionUseCase(
            generadorDeNonce: GeneradorFalso(valor: nonce, bitacora: bitacora),
            hashDeNonce: HashFalso(bitacora: bitacora),
            obtenedor: ObtenedorFalso(resultado: obtenedor ?? .success(credencial), bitacora: bitacora),
            repositorio: repositorio
        )
    }

    private func esperarError(_ esperado: ErrorDeAutenticacion, _ bloque: () async throws -> Sesion,
                              file: StaticString = #filePath, line: UInt = #line) async {
        do {
            _ = try await bloque()
            XCTFail("Se esperaba \(esperado)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? ErrorDeAutenticacion, esperado, file: file, line: line)
        }
    }

    func test_CP158_inicioConGoogleDevuelveLaSesionDelRepositorio() async throws {
        let sesion = try await casoDeUso().ejecutar(.google)

        XCTAssertEqual(sesion, Sesion(usuarioId: "u-1", correo: "a@b.mx"))
        XCTAssertEqual(repositorio.credencialRecibida, credencial)
    }

    func test_CP158_cancelacionDevuelveCanceladoSinLlamarAlRepositorio() async {
        await esperarError(.cancelado) { try await casoDeUso(obtenedor: .failure(.cancelado)).ejecutar(.google) }

        XCTAssertFalse(bitacora.llamadas.contains { $0.hasPrefix("iniciarSesion") })
    }

    func test_CP158_tokenRechazadoDevuelveCredencialRechazada() async {
        repositorio.resultadoDeInicio = .failure(.credencialRechazada)

        await esperarError(.credencialRechazada) { try await casoDeUso().ejecutar(.google) }
    }

    func test_CP158_nonceVacioDevuelveCredencialRechazadaSinLlamarAlObtenedor() async {
        await esperarError(.credencialRechazada) { try await casoDeUso(nonce: "").ejecutar(.google) }

        XCTAssertEqual(bitacora.llamadas, ["generar"])
    }

    /// Falla si se invierten: Google debe recibir el hash y Supabase el nonce crudo.
    func test_CP159_googleRecibeHashYSupabaseRecibeNonceCrudo() async throws {
        _ = try await casoDeUso(nonce: "crudo-123").ejecutar(.google)

        XCTAssertEqual(bitacora.llamadas, [
            "generar",
            "hash(crudo-123)",
            "obtener(google,hash(crudo-123))",
            "iniciarSesion(crudo-123)"
        ])
        XCTAssertEqual(repositorio.nonceRecibido, "crudo-123")
        XCTAssertNotEqual(repositorio.nonceRecibido, "hash(crudo-123)")
    }
}
