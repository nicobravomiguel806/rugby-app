// SP-01 · Reconstruye el estado del partido a partir de sus eventos (event sourcing).
// Espejo en Android: domain/.../rules/MotorDePartido.kt — mismos nombres, mismos casos de prueba.

public enum Lado: CaseIterable, Sendable { case local, visita }

public enum TipoEvento: String, Sendable {
    case ensayo, conversion, penal, drop, ensayoDePenal
    case tarjetaAmarilla, tarjetaRoja, cambio, anulacion
}

public struct EventoDePartido: Equatable, Sendable {
    public let id: String            // UUID generado en el cliente (SP-02)
    public let tipo: TipoEvento
    public let lado: Lado
    public let jugador: Int?
    public let minuto: Int
    public let anulaA: String?

    public init(id: String, tipo: TipoEvento, lado: Lado, jugador: Int? = nil, minuto: Int, anulaA: String? = nil) {
        self.id = id; self.tipo = tipo; self.lado = lado; self.jugador = jugador; self.minuto = minuto; self.anulaA = anulaA
    }
}

public struct EstadoDeEquipo: Equatable, Sendable {
    public var puntos = 0
    public var enCancha: Int
    public var expulsadosDefinitivos: Set<Int> = []
    /// jugador -> minuto en que puede regresar
    public var expulsionesTemporales: [Int: Int] = [:]
    public var cambiosUsados = 0
    public var ensayoPendienteDeConversion = false
}

public struct EstadoDePartido: Equatable, Sendable {
    public var local: EstadoDeEquipo
    public var visita: EstadoDeEquipo
    public subscript(lado: Lado) -> EstadoDeEquipo {
        get { lado == .local ? local : visita }
        set { if lado == .local { local = newValue } else { visita = newValue } }
    }
}

public enum ErrorDeRegla: Error, Equatable {
    case modalidadDesconocida(String)
    case anotacionNoPermitida(TipoEvento, Modalidad)
    case conversionSinEnsayo
    case jugadorExpulsado(Int)
    case sinCambiosDisponibles
    case anulacionInvalida(String)
}

public struct MotorDePartido: Sendable {
    private let reglas: ReglasDeModalidad
    public init(reglas: ReglasDeModalidad) { self.reglas = reglas }

    public func estadoInicial() -> EstadoDePartido {
        .init(local: .init(enCancha: reglas.jugadoresEnCancha), visita: .init(enCancha: reglas.jugadoresEnCancha))
    }

    /// Estado al minuto `alMinuto`. Los eventos anulados se ignoran, no se borran (RNF-13).
    public func calcular(_ eventos: [EventoDePartido], alMinuto: Int = .max) throws -> EstadoDePartido {
        let ids = Set(eventos.map(\.id))
        let anulados = Set(eventos.filter { $0.tipo == .anulacion }.map { $0.anulaA ?? "nil" })
        for a in anulados where !ids.contains(a) { throw ErrorDeRegla.anulacionInvalida(a) }

        var estado = estadoInicial()
        let vigentes = eventos
            .filter { $0.tipo != .anulacion && !anulados.contains($0.id) && $0.minuto <= alMinuto }
            .enumerated().sorted { ($0.element.minuto, $0.offset) < ($1.element.minuto, $1.offset) }  // orden estable, igual que sortedBy de Kotlin
            .map(\.element)
        for ev in vigentes {
            estado = regresarExpulsados(estado, minuto: ev.minuto)
            estado = try aplicar(estado, ev)
        }
        return regresarExpulsados(estado, minuto: alMinuto)
    }

    private func aplicar(_ estadoActual: EstadoDePartido, _ ev: EventoDePartido) throws -> EstadoDePartido {
        var estado = estadoActual
        var equipo = estado[ev.lado]
        if let j = ev.jugador, equipo.expulsadosDefinitivos.contains(j) || equipo.expulsionesTemporales[j] != nil {
            throw ErrorDeRegla.jugadorExpulsado(j)
        }
        switch ev.tipo {
        case .ensayo, .penal, .drop, .ensayoDePenal, .conversion:
            guard reglas.llevaMarcador, let puntos = reglas.puntos(de: ev.tipo) else {
                throw ErrorDeRegla.anotacionNoPermitida(ev.tipo, reglas.modalidad)
            }
            if ev.tipo == .conversion && !equipo.ensayoPendienteDeConversion { throw ErrorDeRegla.conversionSinEnsayo }
            equipo.puntos += puntos
            equipo.ensayoPendienteDeConversion = ev.tipo == .ensayo
        case .tarjetaAmarilla:
            equipo.enCancha -= 1
            equipo.expulsionesTemporales[ev.jugador!] = ev.minuto + reglas.minutosExpulsionTemporal
            equipo.ensayoPendienteDeConversion = false
        case .tarjetaRoja:
            equipo.enCancha -= 1
            equipo.expulsadosDefinitivos.insert(ev.jugador!)
            equipo.ensayoPendienteDeConversion = false
        case .cambio:
            if equipo.cambiosUsados >= reglas.cambiosPermitidos { throw ErrorDeRegla.sinCambiosDisponibles }
            equipo.cambiosUsados += 1
            equipo.ensayoPendienteDeConversion = false
        case .anulacion:
            break
        }
        estado[ev.lado] = equipo
        // Cualquier evento del rival cierra su ventana de conversión.
        let otro: Lado = ev.lado == .local ? .visita : .local
        estado[otro].ensayoPendienteDeConversion = false
        return estado
    }

    private func regresarExpulsados(_ estadoActual: EstadoDePartido, minuto: Int) -> EstadoDePartido {
        var estado = estadoActual
        for lado in Lado.allCases {
            let regresan = estado[lado].expulsionesTemporales.filter { $0.value <= minuto }
            guard !regresan.isEmpty else { continue }
            estado[lado].enCancha += regresan.count
            for k in regresan.keys { estado[lado].expulsionesTemporales.removeValue(forKey: k) }
        }
        return estado
    }
}
