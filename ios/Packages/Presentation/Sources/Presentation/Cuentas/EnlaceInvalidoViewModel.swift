import Observation
import Domain

/// C-02 · De qué correo venía el enlace que ya no sirve (ADR 0008).
public enum TipoDeEnlace: Equatable, Sendable {
    case verificacion
    case recuperacion
}

/// C-02 · Estado de Enlace inválido (CA-8, D-9). Espejo en Android: presentation/.../cuentas/EnlaceInvalidoViewModel.kt.
public enum EstadoDeEnlaceInvalido: Equatable, Sendable {
    /// La app se abrió desde el enlace y no conoce el correo: lo pide antes de reenviar.
    case pidiendoCorreo(errores: [ErrorDeRegistro])
    case listo
    case enviando
    /// Texto neutro de P-9, exista o no la cuenta (AT-11).
    case enviado
    case error(ErrorDeRegistro)
}

/// C-02 · Sin lógica de negocio. Con `.recuperacion` no envía nada: publica `irARecuperar` («Pedir otro enlace»).
@MainActor
@Observable
public final class EnlaceInvalidoViewModel {
    public let tipo: TipoDeEnlace
    public var correo = ""
    public private(set) var estado: EstadoDeEnlaceInvalido
    public private(set) var irARecuperar = false

    private let correoConocido: String?
    private let reenviar: ReenviarVerificacionUseCase

    public init(tipo: TipoDeEnlace, correoConocido: String?, reenviar: ReenviarVerificacionUseCase) {
        self.tipo = tipo
        self.correoConocido = correoConocido.flatMap { $0.isEmpty ? nil : $0 }
        self.reenviar = reenviar
        self.estado = (tipo == .verificacion && self.correoConocido == nil) ? .pidiendoCorreo(errores: []) : .listo
    }

    public var pideCorreo: Bool { tipo == .verificacion && correoConocido == nil }

    public var errores: [ErrorDeRegistro] {
        if case let .pidiendoCorreo(errores) = estado { return errores }
        return []
    }

    /// «Reenviar correo» (solo verificación).
    public func reenviarCorreo() async {
        guard tipo == .verificacion else { return }
        estado = .enviando
        do {
            try await reenviar.ejecutar(correo: correoConocido ?? correo)
            estado = .enviado
        } catch ErrorDeRegistro.correoInvalido {
            estado = .pidiendoCorreo(errores: [.correoInvalido])
        } catch {
            estado = .error(error as? ErrorDeRegistro ?? .desconocido)
        }
    }

    /// «Pedir otro enlace» (solo recuperación): la App abre Recuperar contraseña.
    public func pedirOtroEnlace() {
        guard tipo == .recuperacion else { return }
        irARecuperar = true
    }

    public func yaSeFueARecuperar() {
        irARecuperar = false
    }
}
