import Observation
import Domain

/// C-02 · Estado de Recuperar contraseña (CA-2). Espejo en Android: presentation/.../cuentas/RecuperarContrasenaViewModel.kt.
public enum EstadoDeRecuperarContrasena: Equatable, Sendable {
    case editando(errores: [ErrorDeRecuperacion])
    case enviando
    /// Texto neutro, exista o no la cuenta (AT-11).
    case enviado
    case error(ErrorDeRecuperacion)
}

/// C-02 · Sin lógica de negocio: llama a PedirRecuperacionDeContrasenaUseCase.
@MainActor
@Observable
public final class RecuperarContrasenaViewModel {
    public var correo: String
    public private(set) var estado: EstadoDeRecuperarContrasena = .editando(errores: [])

    private let pedir: PedirRecuperacionDeContrasenaUseCase

    public init(pedir: PedirRecuperacionDeContrasenaUseCase, correo: String = "") {
        self.pedir = pedir
        self.correo = correo
    }

    public var errores: [ErrorDeRecuperacion] {
        if case let .editando(errores) = estado { return errores }
        return []
    }

    public func enviar() async {
        estado = .enviando
        do {
            _ = try await pedir.ejecutar(correo: correo)
            estado = .enviado
        } catch ErrorDeRecuperacion.correoInvalido {
            estado = .editando(errores: [.correoInvalido])
        } catch {
            estado = .error(error as? ErrorDeRecuperacion ?? .desconocido)
        }
    }
}
