import Foundation
import Observation
import Domain
import Presentation

/// C-01 · Navegación de la cuenta (§3.6 del contrato). Vive en App porque solo decide qué pantalla sigue; las reglas
/// están en los casos de uso. Espejo en Android: la navegación de MainActivity.
enum PasoDeCuenta: Hashable {
    case registro, verifica, acceso, aviso, activada, proximamente
}

@MainActor
@Observable
final class NavegacionDeCuenta {
    var mostrarCuenta = false
    var ruta: [PasoDeCuenta] = []
    /// Sin sesión la hoja abre en Bienvenida; con sesión, en Acceso (SP-04).
    private(set) var empiezaEnAcceso = false
    private(set) var registro: RegistroViewModel
    private(set) var sesionActivada: Sesion?
    /// H-6 · Si en esta ejecución ya llegó un enlace del correo (solo en memoria).
    private(set) var llegoUnEnlace = false

    private let contenedor: ContenedorDeDependencias

    init(contenedor: ContenedorDeDependencias) {
        self.contenedor = contenedor
        self.registro = contenedor.registroViewModel()
    }

    var aviso: AvisoDePrivacidadViewModel { contenedor.avisoViewModel }
    var acceso: AccesoViewModel { contenedor.accesoViewModel }
    var urlDelAviso: URL? { contenedor.urlDelAviso }
    var enAviso: Bool { ruta.last == .aviso }

    /// App cerrada sin decidir o cuenta de SP-04 sin aviso: se vuelve a pedir. Sin red no se bloquea (§3.6, CP-164d).
    /// H-6: si llega un enlace del correo antes o durante la consulta, no se pide aquí; lo consulta el flujo del
    /// enlace después de registrar lo marcado en el formulario (CP-164e).
    func alArrancar() async {
        let pedir = await contenedor.hayQuePedirElAvisoAlArrancar.ejecutar(llegoUnEnlace: { [weak self] in
            await self?.llegoUnEnlace ?? true
        })
        guard pedir, !llegoUnEnlace else { return }
        mostrarAviso()
    }

    /// H-6 · Se llama en cuanto llega el enlace, antes de procesarlo, para que el arranque no pida el aviso.
    func anotarEnlace() {
        llegoUnEnlace = true
    }

    func abrirCuenta() async {
        empiezaEnAcceso = await contenedor.obtenerSesionActual.ejecutar() != nil
        ruta = []
        mostrarCuenta = true
    }

    func cambioEnRegistro(_ estado: EstadoDeRegistro) {
        switch estado {
        case .enlaceEnviado:
            if ruta.last != .verifica { ruta.append(.verifica) }
        case let .sesionIniciada(sesion):
            Task { await trasIniciarSesion(sesion, desdeRegistro: true) }
        default:
            break
        }
    }

    func cambioEnAcceso(_ estado: EstadoDeAcceso) {
        if case let .conSesion(sesion) = estado {
            Task { await trasIniciarSesion(sesion, desdeRegistro: false) }
        }
    }

    func cambioEnAviso(_ estado: EstadoDelAviso) async {
        switch estado {
        case .aceptado:
            sesionActivada = await contenedor.obtenerSesionActual.ejecutar()
            ruta = [.activada]
        case .rechazado:
            // CA-9: sesión cerrada y nada guardado. Se olvida también lo marcado en memoria y se vuelve a Bienvenida.
            registro = contenedor.registroViewModel()
            aviso.reiniciar()
            empiezaEnAcceso = false
            ruta = []
            await acceso.cargar()
        default:
            break
        }
    }

    /// `rugbyapp://auth-callback?code=…` (ADR 0008).
    func recibirEnlace(_ enlace: String) async {
        anotarEnlace()
        empiezaEnAcceso = false
        mostrarCuenta = true
        if ruta.last != .verifica { ruta = [.registro, .verifica] }
        await registro.confirmarEnlace(enlace)
    }

    private func trasIniciarSesion(_ sesion: Sesion, desdeRegistro: Bool) async {
        if await aviso.hayQuePedirlo(siFalla: true) {
            mostrarAviso()
        } else if desdeRegistro {
            sesionActivada = sesion
            ruta = [.activada]
        }
    }

    private func mostrarAviso() {
        aviso.reiniciar()
        ruta = [.aviso]
        mostrarCuenta = true
    }
}
