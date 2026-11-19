import Observation
import Domain

/// C-02 · Estado de Nueva contraseña (CA-2, D-7). Espejo en Android: presentation/.../cuentas/NuevaContrasenaViewModel.kt.
public enum EstadoDeNuevaContrasena: Equatable, Sendable {
    /// Canjeando el enlace del correo.
    case confirmando
    case editando(errores: [ErrorDeRecuperacion])
    case guardando
    /// Contraseña cambiada: la sesión queda iniciada y las demás cerradas. La App consulta el aviso (§3.6).
    case guardada(Sesion)
    case error(ErrorDeRecuperacion)
    /// R-3: el canje falló sin conexión o con un error desconocido. Sin sesión de recuperación no hay formulario:
    /// la View ofrece «Reintentar», que canjea otra vez el mismo enlace.
    case canjeFallido(ErrorDeRecuperacion)
    /// El enlace ya no sirve: la App abre Enlace inválido de recuperación.
    case enlaceInvalido
    /// «Cancelar» o «atrás»: la sesión de recuperación se cerró. La App vuelve a Iniciar sesión.
    case abandonada
}

/// C-02 · Sin lógica de negocio: llama a los casos de uso de la recuperación.
@MainActor
@Observable
public final class NuevaContrasenaViewModel {
    public var contrasena = ""
    public private(set) var mostrarContrasena = false
    public private(set) var estado: EstadoDeNuevaContrasena = .confirmando

    private let confirmar: ConfirmarRecuperacionDeContrasenaUseCase
    private let restablecer: RestablecerContrasenaUseCase
    private let cerrarAbandonada: CerrarRecuperacionAbandonadaUseCase
    private var sesion: Sesion?
    /// R-3: el enlace recibido, para reintentar el canje si falló sin conexión.
    private var enlace: String?

    public init(
        confirmar: ConfirmarRecuperacionDeContrasenaUseCase,
        restablecer: RestablecerContrasenaUseCase,
        abandonar: CerrarRecuperacionAbandonadaUseCase
    ) {
        self.confirmar = confirmar
        self.restablecer = restablecer
        self.cerrarAbandonada = abandonar
    }

    public var errores: [ErrorDeRecuperacion] {
        if case let .editando(errores) = estado { return errores }
        return []
    }

    public func alternarContrasena() {
        mostrarContrasena.toggle()
    }

    /// `rugbyapp://recuperar-contrasena?code=…` (ADR 0008).
    public func confirmarEnlace(_ enlace: String) async {
        self.enlace = enlace
        estado = .confirmando
        do {
            sesion = try await confirmar.ejecutar(enlace: enlace)
            estado = .editando(errores: [])
        } catch ErrorDeRecuperacion.enlaceInvalido {
            estado = .enlaceInvalido
        } catch {
            estado = .canjeFallido(error as? ErrorDeRecuperacion ?? .desconocido) // R-3
        }
    }

    /// R-3: vuelve a canjear el enlace guardado tras `canjeFallido`.
    public func reintentarCanje() async {
        guard case .canjeFallido = estado, let enlace else { return }
        await confirmarEnlace(enlace)
    }

    public func guardar() async {
        guard let sesion else { return }
        estado = .guardando
        do {
            try await restablecer.ejecutar(nueva: contrasena)
            estado = .guardada(sesion)
        } catch ErrorDeRecuperacion.contrasenaCorta {
            estado = .editando(errores: [.contrasenaCorta])
        } catch {
            estado = .error(error as? ErrorDeRecuperacion ?? .desconocido)
        }
    }

    /// «Cancelar» o «atrás» (P-7). Si la app se cierra aquí, lo hace el arranque siguiente.
    public func abandonar() async {
        try? await cerrarAbandonada.ejecutar()
        contrasena = ""
        estado = .abandonada
    }
}
