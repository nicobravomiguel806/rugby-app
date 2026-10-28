// SP-01 · Motor de reglas por modalidad.
// Fuente de verdad: docs/domain-model.md §2. Espejo en Android: domain/.../rules/Modalidad.kt
// Domain es Swift puro: no importa Supabase, SwiftUI ni Foundation-UI.

public enum Modalidad: String, CaseIterable, Sendable {
    case sevens = "7"
    case tens = "10"
    case league13 = "13"
    case fifteens = "15"
    case festival = "festival"

    public static func desdeCodigo(_ codigo: String) throws -> Modalidad {
        guard let m = Modalidad(rawValue: codigo) else { throw ErrorDeRegla.modalidadDesconocida(codigo) }
        return m
    }
}

/// Puntos por tipo de anotación. `nil` = la anotación no existe en la modalidad.
public struct Puntuacion: Equatable, Sendable {
    public let ensayo: Int?
    public let conversion: Int?
    public let penal: Int?
    public let drop: Int?
    public let ensayoDePenal: Int?
}

public struct ReglasDeModalidad: Equatable, Sendable {
    public let modalidad: Modalidad
    public let jugadoresEnCancha: Int
    public let tiempos: Int
    public let minutosPorTiempo: Int
    public let minutosExpulsionTemporal: Int
    public let cambiosPermitidos: Int
    public let puntuacion: Puntuacion
    /// Los festivales infantiles no llevan marcador ni cuentan para la tabla.
    public let llevaMarcador: Bool

    private static let union = Puntuacion(ensayo: 5, conversion: 2, penal: 3, drop: 3, ensayoDePenal: 7)
    private static let league = Puntuacion(ensayo: 4, conversion: 2, penal: 2, drop: 1, ensayoDePenal: nil)
    private static let sinMarcador = Puntuacion(ensayo: nil, conversion: nil, penal: nil, drop: nil, ensayoDePenal: nil)

    public static func porDefecto(_ m: Modalidad) -> ReglasDeModalidad {
        switch m {
        case .fifteens: return .init(modalidad: m, jugadoresEnCancha: 15, tiempos: 2, minutosPorTiempo: 40, minutosExpulsionTemporal: 10, cambiosPermitidos: 8, puntuacion: union, llevaMarcador: true)
        case .tens:     return .init(modalidad: m, jugadoresEnCancha: 10, tiempos: 2, minutosPorTiempo: 10, minutosExpulsionTemporal: 2, cambiosPermitidos: 5, puntuacion: union, llevaMarcador: true)
        case .sevens:   return .init(modalidad: m, jugadoresEnCancha: 7, tiempos: 2, minutosPorTiempo: 7, minutosExpulsionTemporal: 2, cambiosPermitidos: 5, puntuacion: union, llevaMarcador: true)
        case .league13: return .init(modalidad: m, jugadoresEnCancha: 13, tiempos: 2, minutosPorTiempo: 40, minutosExpulsionTemporal: 10, cambiosPermitidos: 8, puntuacion: league, llevaMarcador: true)
        case .festival: return .init(modalidad: m, jugadoresEnCancha: 7, tiempos: 2, minutosPorTiempo: 10, minutosExpulsionTemporal: 0, cambiosPermitidos: 99, puntuacion: sinMarcador, llevaMarcador: false)
        }
    }

    public func puntos(de tipo: TipoEvento) -> Int? {
        switch tipo {
        case .ensayo: return puntuacion.ensayo
        case .conversion: return puntuacion.conversion
        case .penal: return puntuacion.penal
        case .drop: return puntuacion.drop
        case .ensayoDePenal: return puntuacion.ensayoDePenal
        default: return 0
        }
    }
}
