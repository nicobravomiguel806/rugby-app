import Foundation
import Observation
import Domain
import Presentation

/// C-01 · Navegación de la cuenta (§3.6 del contrato). Vive en App porque solo decide qué pantalla sigue; las reglas
/// están en los casos de uso. Espejo en Android: la navegación de MainActivity.
/// C-02 · Iniciar sesión, Recuperar contraseña, Nueva contraseña, Enlace inválido y el arranque serializado.
enum PasoDeCuenta: Hashable {
    case registro, verifica, aviso, activada, proximamente
    case iniciarSesion, recuperar, nuevaContrasena, enlaceInvalido
}

@MainActor
@Observable
final class NavegacionDeCuenta {
    var mostrarCuenta = false
    var ruta: [PasoDeCuenta] = []
    /// Sin sesión la hoja abre en Bienvenida; con sesión, en Acceso («Cuenta», SP-04 / P-8).
    private(set) var empiezaEnAcceso = false
    private(set) var registro: RegistroViewModel
    private(set) var iniciarSesion: IniciarSesionViewModel
    private(set) var recuperar: RecuperarContrasenaViewModel
    private(set) var nuevaContrasena: NuevaContrasenaViewModel
    private(set) var enlaceInvalido: EnlaceInvalidoViewModel
    private(set) var sesionActivada: Sesion?
    /// H-6 · Si en esta ejecución ya llegó un enlace del correo (solo en memoria).
    private(set) var llegoUnEnlace = false

    private let contenedor: ContenedorDeDependencias
    /// C-02 · §3.6: recuperación abandonada → revocaciones pendientes (hasta 10 s), antes de cualquier otra acción.
    private var preparacion: Task<Void, Never>?

    init(contenedor: ContenedorDeDependencias) {
        self.contenedor = contenedor
        self.registro = contenedor.registroViewModel()
        self.iniciarSesion = contenedor.iniciarSesionViewModel()
        self.recuperar = contenedor.recuperarContrasenaViewModel(correo: "")
        self.nuevaContrasena = contenedor.nuevaContrasenaViewModel()
        self.enlaceInvalido = contenedor.enlaceInvalidoViewModel(tipo: .verificacion, correoConocido: nil)
    }

    var aviso: AvisoDePrivacidadViewModel { contenedor.avisoViewModel }
    var acceso: AccesoViewModel { contenedor.accesoViewModel }
    var urlDelAviso: URL? { contenedor.urlDelAviso }
    /// Sin gesto para descartar la hoja: en el aviso (CA-9) y en Nueva contraseña (salir = «Cancelar», P-7).
    var sinGestoParaCerrar: Bool { ruta.last == .aviso || ruta.last == .nuevaContrasena }

    /// C-02 · Lo primero del arranque, una sola vez. Los enlaces que lleguen esperan a que termine (§3.6).
    private func prepararArranque() async {
        if preparacion == nil {
            let contenedor = contenedor
            preparacion = Task {
                await Self.prepararConTope(ContenedorDeDependencias.topeDelReintentoAlArrancar,
                                           cerrarAbandonada: contenedor.cerrarRecuperacionAbandonada,
                                           reintentar: contenedor.reintentarRevocaciones)
                contenedor.vigilarLaRed()
            }
        }
        await preparacion?.value
    }

    /// Recuperación abandonada y revocaciones pendientes, antes de cualquier otra acción y bajo el MISMO tope (P-4, R-2):
    /// el cierre de la recuperación también reintenta las pendientes y, sin red, no puede alargar el arranque.
    static func prepararConTope(_ tope: Duration, cerrarAbandonada: CerrarRecuperacionAbandonadaUseCase,
                                reintentar: ReintentarRevocacionesPendientesUseCase) async {
        await conTope(tope) {
            try? await cerrarAbandonada.ejecutar()
            await reintentar.ejecutar()
        }
    }

    /// Corre `trabajo` hasta `tope`; si se pasa, sigue sin esperarlo (P-4: sin red la app no se bloquea).
    private static func conTope(_ tope: Duration, _ trabajo: @escaping @Sendable () async -> Void) async {
        await withTaskGroup(of: Void.self) { grupo in
            grupo.addTask { await trabajo() }
            grupo.addTask { try? await Task.sleep(for: tope) }
            await grupo.next()
            grupo.cancelAll()
        }
    }

    /// App cerrada sin decidir o cuenta de SP-04 sin aviso: se vuelve a pedir. Sin red no se bloquea (§3.6, CP-164d).
    /// H-6: si llega un enlace del correo antes o durante la consulta, no se pide aquí; lo consulta el flujo del
    /// enlace después de registrar lo marcado en el formulario (CP-164e).
    func alArrancar() async {
        await prepararArranque()
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

    // MARK: - Bienvenida e Iniciar sesión

    func irAIniciarSesion() {
        iniciarSesion = contenedor.iniciarSesionViewModel()
        ruta.append(.iniciarSesion)
    }

    func irARecuperar(correo: String) {
        recuperar = contenedor.recuperarContrasenaViewModel(correo: correo)
        ruta.append(.recuperar)
    }

    func cambioEnInicioDeSesion(_ estado: EstadoDeInicioDeSesion) {
        if case let .conSesion(sesion) = estado {
            Task { await trasIniciarSesion(sesion, cerrarHoja: true) }
        }
    }

    func cambioEnRegistro(_ estado: EstadoDeRegistro) {
        switch estado {
        case .enlaceEnviado:
            if ruta.last != .verifica { ruta.append(.verifica) }
        case let .sesionIniciada(sesion):
            Task { await trasIniciarSesion(sesion, desdeRegistro: true) }
        case .error(.enlaceInvalido):
            // C-02 · CA-8: pantalla Enlace inválido. Si la app se abrió desde el enlace no conoce el correo y lo pide.
            let correo = registro.correo.trimmingCharacters(in: .whitespacesAndNewlines)
            enlaceInvalido = contenedor.enlaceInvalidoViewModel(tipo: .verificacion, correoConocido: correo.isEmpty ? nil : correo)
            ruta = [.enlaceInvalido]
        default:
            break
        }
    }

    func cambioEnAcceso(_ estado: EstadoDeAcceso) {
        switch estado {
        case let .conSesion(sesion):
            Task { await trasIniciarSesion(sesion) }
        case .sinSesion where empiezaEnAcceso:
            // C-02 · CA-3: tras cerrar sesión vuelve a Bienvenida y se olvida lo escrito en memoria.
            reiniciarCuenta()
        default:
            break
        }
    }

    func cambioEnAviso(_ estado: EstadoDelAviso) async {
        switch estado {
        case .aceptado:
            sesionActivada = await contenedor.obtenerSesionActual.ejecutar()
            ruta = [.activada]
        case .rechazado:
            // CA-9: sesión cerrada y nada guardado. Se olvida también lo marcado en memoria y se vuelve a Bienvenida.
            reiniciarCuenta()
            await acceso.cargar()
        default:
            break
        }
    }

    // MARK: - Enlaces del correo (ADR 0008)

    /// `rugbyapp://auth-callback?code=…`.
    func recibirEnlace(_ enlace: String) async {
        anotarEnlace()
        await prepararArranque()
        empiezaEnAcceso = false
        mostrarCuenta = true
        if ruta.last != .verifica { ruta = [.registro, .verifica] }
        await registro.confirmarEnlace(enlace)
    }

    /// C-02 · `rugbyapp://recuperar-contrasena?code=…`. Espera al arranque: si no, la recuperación abandonada de antes
    /// podría cerrar la sesión recién canjeada.
    func recibirEnlaceDeRecuperacion(_ enlace: String) async {
        anotarEnlace()
        await prepararArranque()
        empiezaEnAcceso = false
        mostrarCuenta = true
        nuevaContrasena = contenedor.nuevaContrasenaViewModel()
        ruta = [.nuevaContrasena]
        await nuevaContrasena.confirmarEnlace(enlace)
    }

    func cambioEnNuevaContrasena(_ estado: EstadoDeNuevaContrasena) {
        switch estado {
        case .enlaceInvalido:
            enlaceInvalido = contenedor.enlaceInvalidoViewModel(tipo: .recuperacion, correoConocido: nil)
            ruta = [.enlaceInvalido]
        case let .guardada(sesion):
            Task { await trasIniciarSesion(sesion, cerrarHoja: true) }
        case .abandonada:
            // P-7: se cierra la sesión de recuperación y vuelve a Iniciar sesión.
            iniciarSesion = contenedor.iniciarSesionViewModel()
            ruta = [.iniciarSesion]
        default:
            break
        }
    }

    func cambioEnEnlaceInvalido(irARecuperar: Bool) {
        guard irARecuperar else { return }
        enlaceInvalido.yaSeFueARecuperar()
        self.irARecuperar(correo: "")
    }

    // MARK: - Apoyo

    /// `desdeRegistro`: muestra Cuenta activada. `cerrarHoja` (C-02, Iniciar sesión y Nueva contraseña): se cierra la
    /// hoja y queda el Inicio provisional (§3.6; la barra de pestañas llega en C-08). Acceso no cierra la hoja.
    private func trasIniciarSesion(_ sesion: Sesion, desdeRegistro: Bool = false, cerrarHoja: Bool = false) async {
        if await aviso.hayQuePedirlo(siFalla: true) {
            mostrarAviso()
        } else if desdeRegistro {
            sesionActivada = sesion
            ruta = [.activada]
        } else if cerrarHoja {
            mostrarCuenta = false
            ruta = []
        }
    }

    /// Se crean de nuevo los VM de la cuenta: lo escrito o marcado en memoria se olvida (CA-3).
    private func reiniciarCuenta() {
        registro = contenedor.registroViewModel()
        iniciarSesion = contenedor.iniciarSesionViewModel()
        recuperar = contenedor.recuperarContrasenaViewModel(correo: "")
        nuevaContrasena = contenedor.nuevaContrasenaViewModel()
        aviso.reiniciar()
        empiezaEnAcceso = false
        ruta = []
    }

    private func mostrarAviso() {
        aviso.reiniciar()
        ruta = [.aviso]
        mostrarCuenta = true
    }
}
