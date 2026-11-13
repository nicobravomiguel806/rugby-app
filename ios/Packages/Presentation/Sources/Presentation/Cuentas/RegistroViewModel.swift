import Observation
import Domain

/// C-01 · Estado de las pantallas Registro y Verifica tu correo. Espejo en Android: presentation/.../cuentas/RegistroViewModel.kt.
public enum EstadoDeRegistro: Equatable, Sendable {
    /// Formulario abierto; `errores` son los de validación, en el orden de Domain (CP-160f).
    case editando(errores: [ErrorDeRegistro])
    case enviando
    /// Mensaje neutro: igual para un correo nuevo y para uno con cuenta (P-7).
    case enlaceEnviado(correo: String)
    case error(ErrorDeRegistro)
    /// Error del inicio con Google desde Registro.
    case errorDeGoogle(ErrorDeAutenticacion)
    /// Canjeando el enlace del correo.
    case confirmando
    /// Hay sesión (por el enlace o por Google). La App consulta el aviso antes de Sesión iniciada (§3.6).
    case sesionIniciada(Sesion)
}

/// Resultado de «Reenviar enlace» en Verifica tu correo.
public enum EstadoDeReenvio: Equatable, Sendable {
    case enviado
    case error(ErrorDeRegistro)
}

/// C-01 · Sin lógica de negocio: guarda lo que se escribe y llama a los casos de uso. Lo marcado en el formulario
/// (aviso y finalidades) vive solo en memoria hasta volver del enlace (AT-17).
@MainActor
@Observable
public final class RegistroViewModel {
    public var nombreCompleto = ""
    public var correo = ""
    public var contrasena = ""
    public var aceptoAvisoDePrivacidad = false
    public private(set) var finalidades: Set<FinalidadSecundaria> = []
    public private(set) var estado: EstadoDeRegistro = .editando(errores: [])
    public private(set) var reenvio: EstadoDeReenvio?

    private let registrar: RegistrarUsuarioUseCase
    private let reenviar: ReenviarVerificacionUseCase
    private let confirmarCorreo: ConfirmarCorreoUseCase
    private let aceptarAviso: AceptarAvisoDePrivacidadUseCase
    private let iniciarSesion: IniciarSesionUseCase
    /// Correo del último registro enviado; el enlace que llegue se asocia a lo marcado para ese correo.
    private var correoRegistrado: String?

    public init(
        registrar: RegistrarUsuarioUseCase,
        reenviar: ReenviarVerificacionUseCase,
        confirmarCorreo: ConfirmarCorreoUseCase,
        aceptarAviso: AceptarAvisoDePrivacidadUseCase,
        iniciarSesion: IniciarSesionUseCase
    ) {
        self.registrar = registrar
        self.reenviar = reenviar
        self.confirmarCorreo = confirmarCorreo
        self.aceptarAviso = aceptarAviso
        self.iniciarSesion = iniciarSesion
    }

    /// Cada finalidad se marca y desmarca por separado (A-1).
    public func alternar(_ finalidad: FinalidadSecundaria) {
        if finalidades.contains(finalidad) { finalidades.remove(finalidad) } else { finalidades.insert(finalidad) }
    }

    public var errores: [ErrorDeRegistro] {
        if case let .editando(errores) = estado { return errores }
        return []
    }

    public func crearCuenta() async {
        estado = .enviando
        let datos = DatosDeRegistro(
            nombreCompleto: nombreCompleto,
            correo: correo,
            contrasena: contrasena,
            aceptoAvisoDePrivacidad: aceptoAvisoDePrivacidad,
            finalidadesAceptadas: finalidades
        )
        do {
            let resultado = try await registrar.ejecutar(datos)
            if case let .enlaceEnviado(correo) = resultado {
                correoRegistrado = correo
                estado = .enlaceEnviado(correo: correo)
            }
        } catch let error as ErroresDeValidacion {
            estado = .editando(errores: error.errores)
        } catch {
            estado = .error(error as? ErrorDeRegistro ?? .desconocido)
        }
    }

    /// Vuelve al formulario tras un error del servidor, sin perder lo escrito.
    public func volverAEditar() {
        estado = .editando(errores: [])
    }

    public func reenviarEnlace() async {
        guard let correo = correoRegistrado ?? (correo.isEmpty ? nil : correo) else { return }
        reenvio = nil
        do {
            try await reenviar.ejecutar(correo: correo)
            reenvio = .enviado
        } catch {
            reenvio = .error(error as? ErrorDeRegistro ?? .desconocido)
        }
    }

    /// El enlace del correo. Si lo marcado en el formulario sigue en memoria, se registra el aviso con esas
    /// finalidades; si no (o si falla), la App lo pide en la pantalla Aviso de privacidad (§3.6).
    public func confirmarEnlace(_ enlace: String) async {
        estado = .confirmando
        do {
            let sesion = try await confirmarCorreo.ejecutar(enlace: enlace)
            if correoRegistrado != nil, aceptoAvisoDePrivacidad {
                try? await aceptarAviso.ejecutar(finalidades: finalidades)
            }
            estado = .sesionIniciada(sesion)
        } catch {
            estado = .error(error as? ErrorDeRegistro ?? .desconocido)
        }
    }

    public func continuarConGoogle() async {
        estado = .enviando
        do {
            estado = .sesionIniciada(try await iniciarSesion.ejecutar(.google))
        } catch ErrorDeAutenticacion.cancelado {
            estado = .editando(errores: []) // cerrar la hoja de Google no es un error que mostrar
        } catch {
            estado = .errorDeGoogle(error as? ErrorDeAutenticacion ?? .desconocido)
        }
    }
}
