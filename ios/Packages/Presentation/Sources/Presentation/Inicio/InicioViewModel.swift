import Observation
import Domain

/// T-03 · Pantalla Inicio provisional (P-2). Solo pide las modalidades al caso de uso inyectado.
/// Espejo en Android: presentation/.../inicio/InicioViewModel.kt.
@MainActor
@Observable
public final class InicioViewModel {
    public private(set) var modalidades: [ReglasDeModalidad] = []

    private let obtenerModalidades: ObtenerModalidadesUseCase

    public init(obtenerModalidades: ObtenerModalidadesUseCase) {
        self.obtenerModalidades = obtenerModalidades
    }

    public func cargar() {
        modalidades = obtenerModalidades.ejecutar()
    }
}
