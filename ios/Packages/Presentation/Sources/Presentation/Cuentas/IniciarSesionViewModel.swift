import Observation
import Domain

/// C-02 · Estado de Iniciar sesión (D-5, D-6). Espejo en Android: presentation/.../cuentas/IniciarSesionViewModel.kt.
public enum EstadoDeInicioDeSesion: Equatable, Sendable {
    /// Formulario abierto; `errores` son los de validación de Domain (correo inválido).
    case editando(errores: [ErrorDeAutenticacion])
    case enviando
    /// Hay sesión. La App consulta el aviso antes de cerrar la hoja (§3.6).
    case conSesion(Sesion)
    case error(ErrorDeAutenticacion)
    /// Error del inicio con Google desde esta pantalla (su texto es el de Google).
    case errorDeGoogle(ErrorDeAutenticacion)
    /// La cuenta no ha abierto el enlace de verificación: se ofrece «Reenviar correo».
    case correoSinVerificar(correo: String)
}

/// C-02 · Sin lógica de negocio: guarda lo que se escribe y llama a los casos de uso.
@MainActor
@Observable
public final class IniciarSesionViewModel {
    public var correo = ""
    public var contrasena = ""
    public private(set) var mostrarContrasena = false
    public private(set) var estado: EstadoDeInicioDeSesion = .editando(errores: [])
    public private(set) var reenvio: EstadoDeReenvio?

    private let iniciarConCorreo: IniciarSesionConCorreoUseCase
    private let iniciarConGoogle: IniciarSesionUseCase
    private let reenviar: ReenviarVerificacionUseCase

    public init(
        iniciarConCorreo: IniciarSesionConCorreoUseCase,
        iniciarConGoogle: IniciarSesionUseCase,
        reenviar: ReenviarVerificacionUseCase
    ) {
        self.iniciarConCorreo = iniciarConCorreo
        self.iniciarConGoogle = iniciarConGoogle
        self.reenviar = reenviar
    }

    public var errores: [ErrorDeAutenticacion] {
        if case let .editando(errores) = estado { return errores }
        return []
    }

    public var enviando: Bool { estado == .enviando }

    public func alternarContrasena() {
        mostrarContrasena.toggle()
    }

    public func iniciarSesion() async {
        estado = .enviando
        reenvio = nil
        do {
            estado = .conSesion(try await iniciarConCorreo.ejecutar(CredencialesDeCorreo(correo: correo, contrasena: contrasena)))
        } catch ErrorDeAutenticacion.correoInvalido {
            estado = .editando(errores: [.correoInvalido])
        } catch ErrorDeAutenticacion.correoSinVerificar {
            estado = .correoSinVerificar(correo: correo)
        } catch {
            estado = .error(error as? ErrorDeAutenticacion ?? .desconocido)
        }
    }

    public func continuarConGoogle() async {
        estado = .enviando
        do {
            estado = .conSesion(try await iniciarConGoogle.ejecutar(.google))
        } catch ErrorDeAutenticacion.cancelado {
            estado = .editando(errores: []) // cerrar la hoja de Google no es un error que mostrar
        } catch {
            estado = .errorDeGoogle(error as? ErrorDeAutenticacion ?? .desconocido)
        }
    }

    /// «Reenviar correo» con la cuenta sin verificar (P-5).
    public func reenviarCorreo() async {
        guard case let .correoSinVerificar(correo) = estado else { return }
        reenvio = nil
        do {
            try await reenviar.ejecutar(correo: correo)
            reenvio = .enviado
        } catch {
            reenvio = .error(error as? ErrorDeRegistro ?? .desconocido)
        }
    }

    /// Vuelve al formulario sin perder lo escrito (al editar después de un error).
    public func volverAEditar() {
        if case .editando = estado { return }
        estado = .editando(errores: [])
    }
}
