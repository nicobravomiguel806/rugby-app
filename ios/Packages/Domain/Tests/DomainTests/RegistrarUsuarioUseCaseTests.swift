import XCTest
@testable import Domain

/// C-01 · CP-160 (validación del registro) y CP-114a/e (aviso en el formulario). Reglas de domain-model.md §1.
/// Mismos casos que android/domain/src/test/kotlin/mx/rugbyapp/domain/cuentas/RegistrarUsuarioUseCaseTest.kt.
final class RegistrarUsuarioUseCaseTests: XCTestCase {
    private func datos(
        nombre: String = "Daniela Pérez",
        correo: String = "daniela@ejemplo.mx",
        contrasena: String = "contrasena-larga",
        aviso: Bool = true
    ) -> DatosDeRegistro {
        DatosDeRegistro(nombreCompleto: nombre, correo: correo, contrasena: contrasena, aceptoAvisoDePrivacidad: aviso)
    }

    private func caso(_ repositorio: RepositorioDeRegistroFalso) -> RegistrarUsuarioUseCase {
        RegistrarUsuarioUseCase(validador: ValidadorDeRegistro(), repositorio: repositorio)
    }

    private func erroresAlRegistrar(_ d: DatosDeRegistro, _ repositorio: RepositorioDeRegistroFalso,
                                    file: StaticString = #filePath, line: UInt = #line) async -> [ErrorDeRegistro] {
        do {
            _ = try await caso(repositorio).ejecutar(d)
            XCTFail("Se esperaban errores de validación", file: file, line: line)
            return []
        } catch let error as ErroresDeValidacion {
            return error.errores
        } catch {
            XCTFail("Error inesperado: \(error)", file: file, line: line)
            return []
        }
    }

    func test_CP160a_datosValidosLlamanAlRepositorioUnaVezYDevuelvenEnlaceEnviado() async throws {
        let repositorio = RepositorioDeRegistroFalso()

        let resultado = try await caso(repositorio).ejecutar(datos(correo: "Daniela@Ejemplo.mx"))

        XCTAssertEqual(resultado, .enlaceEnviado(correo: "daniela@ejemplo.mx"))
        XCTAssertEqual(repositorio.registrados.count, 1)
    }

    func test_CP160b_nombreVacioOSoloEspaciosEsNombreInvalidoSinLlamarAlRepositorio() async {
        for nombre in ["", "    "] {
            let repositorio = RepositorioDeRegistroFalso()
            let errores = await erroresAlRegistrar(datos(nombre: nombre), repositorio)
            XCTAssertEqual(errores, [.nombreInvalido], "nombre «\(nombre)»")
            XCTAssertTrue(repositorio.registrados.isEmpty)
        }
    }

    func test_CP160c_limitesDelNombreTrasQuitarEspacios() {
        let validador = ValidadorDeRegistro()
        XCTAssertEqual(validador.validar(datos(nombre: "  A  ")), [.nombreInvalido])
        XCTAssertEqual(validador.validar(datos(nombre: " Al ")), [])
        XCTAssertEqual(validador.validar(datos(nombre: String(repeating: "a", count: 120))), [])
        XCTAssertEqual(validador.validar(datos(nombre: " " + String(repeating: "a", count: 120) + " ")), [])
        XCTAssertEqual(validador.validar(datos(nombre: String(repeating: "a", count: 121))), [.nombreInvalido])
    }

    func test_CP160d_correoSinArrobaOSinDominioEsCorreoInvalido() {
        let validador = ValidadorDeRegistro()
        for correo in ["danielaejemplo.mx", "daniela@", "daniela@ejemplo", "@ejemplo.mx", "daniela@.mx", "dani ela@ejemplo.mx", ""] {
            XCTAssertEqual(validador.validar(datos(correo: correo)), [.correoInvalido], "correo «\(correo)»")
        }
        XCTAssertEqual(validador.validar(datos(correo: "  daniela@ejemplo.mx  ")), [])
    }

    func test_CP160e_contrasenaDe9EsCortaYDe10EsValidaSinReglasDeComposicion() {
        let validador = ValidadorDeRegistro()
        XCTAssertEqual(validador.validar(datos(contrasena: "123456789")), [.contrasenaCorta])
        XCTAssertEqual(validador.validar(datos(contrasena: "1234567890")), [])
        XCTAssertEqual(validador.validar(datos(contrasena: "aaaaaaaaaa")), [])
    }

    func test_CP160f_variosErroresSeDevuelvenTodosEnOrdenFijo() async {
        let repositorio = RepositorioDeRegistroFalso()

        let errores = await erroresAlRegistrar(datos(nombre: " ", correo: "x", contrasena: "corta", aviso: false), repositorio)

        XCTAssertEqual(errores, [.nombreInvalido, .correoInvalido, .contrasenaCorta, .avisoNoAceptado])
        XCTAssertTrue(repositorio.registrados.isEmpty)
    }

    func test_CP160g_elRepositorioRecibeLosDatosNormalizadosYLaContrasenaSinCambios() async throws {
        let repositorio = RepositorioDeRegistroFalso()

        _ = try await caso(repositorio).ejecutar(datos(nombre: "  Daniela Pérez ", correo: "  Daniela@Ejemplo.MX ", contrasena: "  Clave Con Espacios  "))

        let recibido = try XCTUnwrap(repositorio.registrados.first)
        XCTAssertEqual(recibido.correo, "daniela@ejemplo.mx")
        XCTAssertEqual(recibido.nombreCompleto, "Daniela Pérez")
        XCTAssertEqual(recibido.contrasena, "  Clave Con Espacios  ")
    }

    func test_CP160i_unErrorDelRepositorioSePropagaSinTransformarse() async {
        for esperado in [ErrorDeRegistro.demasiadosIntentos, .sinConexion] {
            let repositorio = RepositorioDeRegistroFalso()
            repositorio.errorAlRegistrar = esperado
            do {
                _ = try await caso(repositorio).ejecutar(datos())
                XCTFail("Se esperaba \(esperado)")
            } catch {
                XCTAssertEqual(error as? ErrorDeRegistro, esperado)
            }
        }
    }

    func test_CP160i_reenviarVerificacionPropagaElErrorSinTransformarse() async {
        let repositorio = RepositorioDeRegistroFalso()
        repositorio.errorAlRegistrar = .demasiadosIntentos
        do {
            try await ReenviarVerificacionUseCase(repositorio: repositorio).ejecutar(correo: "daniela@ejemplo.mx")
            XCTFail("Se esperaba demasiadosIntentos")
        } catch {
            XCTAssertEqual(error as? ErrorDeRegistro, .demasiadosIntentos)
        }
        XCTAssertEqual(repositorio.reenvios, ["daniela@ejemplo.mx"])
    }

    func test_CP160j_laDescripcionDeLosDatosNoContieneLaContrasena() {
        let d = datos(contrasena: "secreta-1234567")
        XCTAssertFalse(String(describing: d).contains("secreta-1234567"))
        XCTAssertFalse(String(reflecting: d).contains("secreta-1234567"))
        XCTAssertFalse("\(d)".contains("secreta-1234567"))
    }

    func test_CP114a_sinAceptarElAvisoEsAvisoNoAceptadoYElRepositorioNoRecibeNada() async {
        let repositorio = RepositorioDeRegistroFalso()

        let errores = await erroresAlRegistrar(datos(aviso: false), repositorio)

        XCTAssertEqual(errores, [.avisoNoAceptado])
        XCTAssertTrue(repositorio.registrados.isEmpty)
    }

    func test_CP114e_sinIndicarFinalidadesLasTresQuedanDesmarcadas() {
        XCTAssertEqual(datos().finalidadesAceptadas, [])
    }
}
