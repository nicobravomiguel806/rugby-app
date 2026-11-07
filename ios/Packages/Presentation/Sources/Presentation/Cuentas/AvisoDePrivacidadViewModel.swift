import Observation
import Domain

/// C-01 · Estado de la pantalla Aviso de privacidad (CA-2, CA-4, CA-9). Espejo en Android: presentation/.../cuentas/AvisoDePrivacidadViewModel.kt.
public enum EstadoDelAviso: Equatable, Sendable {
    case pendiente
    case enviando
    case aceptado
    /// «No acepto»: la sesión se cerró y no se guardó nada (CA-9). La App vuelve a Bienvenida.
    case rechazado
    case error(ErrorDeConsentimiento)
    /// No se pudo borrar la sesión local al rechazar: se queda en la pantalla y se puede reintentar (CP-164c).
    case errorAlCerrarSesion
}

/// C-01 · Sin lógica de negocio: llama a los casos de uso y publica el estado.
@MainActor
@Observable
public final class AvisoDePrivacidadViewModel {
    public var aceptoAvisoDePrivacidad = false
    public private(set) var finalidades: Set<FinalidadSecundaria> = []
    public private(set) var estado: EstadoDelAviso = .pendiente

    private let aceptar: AceptarAvisoDePrivacidadUseCase
    private let rechazarUseCase: RechazarAvisoDePrivacidadUseCase
    private let consultar: ConsultarAvisoAceptadoUseCase
    private let obtenerSesionActual: ObtenerSesionActualUseCase

    public init(
        aceptar: AceptarAvisoDePrivacidadUseCase,
        rechazar: RechazarAvisoDePrivacidadUseCase,
        consultar: ConsultarAvisoAceptadoUseCase,
        obtenerSesionActual: ObtenerSesionActualUseCase
    ) {
        self.aceptar = aceptar
        self.rechazarUseCase = rechazar
        self.consultar = consultar
        self.obtenerSesionActual = obtenerSesionActual
    }

    /// «Aceptar y continuar» solo con la casilla obligatoria marcada.
    public var puedeAceptar: Bool { aceptoAvisoDePrivacidad && estado != .enviando }

    public func alternar(_ finalidad: FinalidadSecundaria) {
        if finalidades.contains(finalidad) { finalidades.remove(finalidad) } else { finalidades.insert(finalidad) }
    }

    /// Hay sesión y el servidor dice que no aceptó la versión vigente. Si la consulta falla, devuelve
    /// `siFalla`: al arrancar no se bloquea (`false`); justo después de iniciar sesión se pide (`true`) (§3.6).
    public func hayQuePedirlo(siFalla: Bool) async -> Bool {
        guard await obtenerSesionActual.ejecutar() != nil else { return false }
        do {
            return try await !consultar.ejecutar()
        } catch {
            return siFalla
        }
    }

    /// Deja la pantalla como nueva (las tres casillas desmarcadas, A-1).
    public func reiniciar() {
        aceptoAvisoDePrivacidad = false
        finalidades = []
        estado = .pendiente
    }

    public func aceptarYContinuar() async {
        guard aceptoAvisoDePrivacidad else { return }
        estado = .enviando
        do {
            try await aceptar.ejecutar(finalidades: finalidades)
            estado = .aceptado
        } catch {
            estado = .error(error as? ErrorDeConsentimiento ?? .desconocido)
        }
    }

    public func rechazar() async {
        estado = .enviando
        do {
            try await rechazarUseCase.ejecutar()
            aceptoAvisoDePrivacidad = false
            finalidades = []
            estado = .rechazado
        } catch {
            estado = .errorAlCerrarSesion
        }
    }
}
