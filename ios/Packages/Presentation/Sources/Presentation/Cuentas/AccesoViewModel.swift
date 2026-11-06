import Observation
import Domain

/// SP-04 · Estado de la pantalla provisional Acceso (P-6). Espejo en Android: presentation/.../cuentas/AccesoViewModel.kt.
public enum EstadoDeAcceso: Equatable, Sendable {
    case cargando
    case sinSesion
    case conSesion(Sesion)
    case error(ErrorDeAutenticacion)
}

/// SP-04 · Sin lógica de negocio: solo llama a los casos de uso y publica el estado.
@MainActor
@Observable
public final class AccesoViewModel {
    public private(set) var estado: EstadoDeAcceso = .cargando

    private let iniciarSesion: IniciarSesionUseCase
    private let obtenerSesionActual: ObtenerSesionActualUseCase
    private let cerrarSesionUseCase: CerrarSesionUseCase

    public init(
        iniciarSesion: IniciarSesionUseCase,
        obtenerSesionActual: ObtenerSesionActualUseCase,
        cerrarSesion: CerrarSesionUseCase
    ) {
        self.iniciarSesion = iniciarSesion
        self.obtenerSesionActual = obtenerSesionActual
        self.cerrarSesionUseCase = cerrarSesion
    }

    public func cargar() async {
        estado = .cargando
        estado = await obtenerSesionActual.ejecutar().map(EstadoDeAcceso.conSesion) ?? .sinSesion
    }

    public func iniciarConGoogle() async {
        estado = .cargando
        do {
            estado = .conSesion(try await iniciarSesion.ejecutar(.google))
        } catch ErrorDeAutenticacion.cancelado {
            estado = .sinSesion // cerrar la hoja de Google no es un error que mostrar
        } catch {
            estado = .error(error as? ErrorDeAutenticacion ?? .desconocido)
        }
    }

    public func cerrarSesion() async {
        estado = .cargando
        do {
            try await cerrarSesionUseCase.ejecutar()
            estado = .sinSesion
        } catch {
            estado = .error(error as? ErrorDeAutenticacion ?? .desconocido)
        }
    }
}
