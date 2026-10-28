import Foundation
import Observation
import Domain

/// MVVM: el ViewModel solo traduce entre la pantalla y Domain. Las reglas están en MotorDePartido (SP-01)
/// y la persistencia offline en ColaDeSincronizacion (SP-02). Pantalla: frame "V-02 · Partido en vivo" en Figma.
@MainActor
@Observable
public final class PartidoEnVivoViewModel {
    public private(set) var estado: EstadoDePartido
    public private(set) var eventos: [EventoDePartido] = []
    public private(set) var pendientesDeEnviar = 0
    public private(set) var mensajeDeError: String?
    public var minuto = 0

    private let reglas: ReglasDeModalidad
    private let motor: MotorDePartido
    private let cola: ColaDeSincronizacion

    public init(reglas: ReglasDeModalidad, cola: ColaDeSincronizacion) {
        self.reglas = reglas
        self.motor = MotorDePartido(reglas: reglas)
        self.cola = cola
        self.estado = motor.estadoInicial()
    }

    /// Botones que la pantalla debe mostrar: solo los que existen en la modalidad.
    public var anotacionesDisponibles: [TipoEvento] {
        guard reglas.llevaMarcador else { return [] }
        return [.ensayo, .conversion, .penal, .drop, .ensayoDePenal].filter { reglas.puntos(de: $0) != nil }
    }

    public func registrar(_ tipo: TipoEvento, lado: Lado, jugador: Int? = nil) {
        let nuevo = EventoDePartido(id: UUID().uuidString, tipo: tipo, lado: lado, jugador: jugador, minuto: minuto)
        do {
            estado = try motor.calcular(eventos + [nuevo], alMinuto: minuto)   // valida antes de guardar
            eventos.append(nuevo)
            cola.encolar(id: nuevo.id, payload: "\(tipo.rawValue)|\(lado)|\(minuto)")
            pendientesDeEnviar += 1
            mensajeDeError = nil
        } catch let error as ErrorDeRegla {
            mensajeDeError = Self.texto(de: error)
        } catch {
            mensajeDeError = "No se pudo registrar el evento"
        }
    }

    public func anular(_ evento: EventoDePartido) {
        let anulacion = EventoDePartido(id: UUID().uuidString, tipo: .anulacion, lado: evento.lado, minuto: minuto, anulaA: evento.id)
        eventos.append(anulacion)
        estado = (try? motor.calcular(eventos, alMinuto: minuto)) ?? estado
        cola.encolar(id: anulacion.id, payload: "anulacion|\(evento.id)")
        pendientesDeEnviar += 1
    }

    static func texto(de error: ErrorDeRegla) -> String {
        switch error {
        case .conversionSinEnsayo: return "La conversión debe ir después de un ensayo"
        case .jugadorExpulsado(let n): return "El \(n) está expulsado"
        case .sinCambiosDisponibles: return "Ya no quedan cambios"
        case .anotacionNoPermitida: return "Esta anotación no existe en la modalidad"
        default: return "Evento no válido"
        }
    }
}
