import Foundation
import Observation
import os
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
    /// C-02 · Ronda 2+3: cuántos canjes de enlaces del correo se iniciaron en esta ejecución (uno por enlace).
    private(set) var canjesIniciados = 0
    /// Enlaces del correo ya recibidos en esta ejecución (solo en memoria, nunca se registran): si la misma URL llega
    /// por `connectionOptions` y por `onOpenURL`, el segundo no vuelve a canjear.
    private var enlacesRecibidos: Set<String> = []

    private let contenedor: ContenedorDeDependencias
    /// C-02 · §3.6: la recuperación abandonada se cierra antes de cualquier otra acción (hasta 10 s, R-2).
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
                await Self.prepararConTope(ContenedorDeDependencias.topeDelArranque,
                                           cerrarAbandonada: contenedor.cerrarRecuperacionAbandonada)
            }
        }
        await preparacion?.value
    }

    /// Recuperación abandonada, antes de cualquier otra acción y con tope (R-2): cerrar la sesión intenta revocarla en el
    /// servidor y, sin red, no puede alargar el arranque (ADR 0011).
    static func prepararConTope(_ tope: Duration, cerrarAbandonada: CerrarRecuperacionAbandonadaUseCase) async {
        await conTope(tope) {
            try? await cerrarAbandonada.ejecutar()
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
        case .error(.enlaceInvalido) where ruta.last == .verifica:
            // C-02 · CA-8: pantalla Enlace inválido. Si la app se abrió desde el enlace no conoce el correo y lo pide.
            // R-6: solo desde Verifica tu correo (donde se canjea), así llegar dos veces no la repite.
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

    /// C-02 · Ronda 2+3: punto de entrada único de los enlaces del correo, llegue por `onOpenURL` o por las opciones de
    /// conexión de la escena (arranque en frío). Devuelve la tarea del canje, o `nil` si la URL no es del correo.
    @discardableResult
    func recibirURL(_ url: URL, camino: CaminoDelEnlace) -> Task<Void, Never>? {
        let clase = ClaseDeEnlace(url)
        RegistroDeEnlaces.logger.notice("llega por \(camino.rawValue, privacy: .public): enlace=\(clase.rawValue, privacy: .public) error=\(ClaseDeEnlace.traeError(url), privacy: .public)")
        switch clase {
        case .verificacion:
            anotarEnlace() // H-6: antes de la tarea, para que alArrancar no pida el aviso
            return Task { await recibirEnlace(url.absoluteString) }
        case .recuperacion:
            anotarEnlace()
            return Task { await recibirEnlaceDeRecuperacion(url.absoluteString) }
        case .otro:
            return nil
        }
    }

    /// `rugbyapp://auth-callback?code=…`.
    func recibirEnlace(_ enlace: String) async {
        anotarEnlace()
        guard esNuevo(enlace, clase: .verificacion) else { return }
        await prepararArranque()
        empiezaEnAcceso = false
        mostrarCuenta = true
        if ruta.last != .verifica { ruta = [.registro, .verifica] }
        canjesIniciados += 1
        await registro.confirmarEnlace(enlace)
        irAEnlaceInvalidoSiElCanjeFallo()
    }

    /// C-02 · `rugbyapp://recuperar-contrasena?code=…`. Espera al arranque: si no, la recuperación abandonada de antes
    /// podría cerrar la sesión recién canjeada.
    func recibirEnlaceDeRecuperacion(_ enlace: String) async {
        anotarEnlace()
        guard esNuevo(enlace, clase: .recuperacion) else { return }
        await prepararArranque()
        empiezaEnAcceso = false
        mostrarCuenta = true
        nuevaContrasena = contenedor.nuevaContrasenaViewModel()
        ruta = [.nuevaContrasena]
        canjesIniciados += 1
        await nuevaContrasena.confirmarEnlace(enlace)
        irAEnlaceInvalidoSiElCanjeFallo()
    }

    /// C-02 · R-6 (CA-8): Enlace inválido se deriva del estado actual de los ViewModel que guarda esta navegación, no de
    /// un cambio observado por la vista. En frío el canje falla antes de que la hoja se presente y su `.onChange` no se
    /// entera. Se llama al terminar el canje y al aparecer la hoja; si ya se navegó, no hace nada.
    func irAEnlaceInvalidoSiElCanjeFallo() {
        if registro.estado == .error(.enlaceInvalido) { cambioEnRegistro(registro.estado) }
        if nuevaContrasena.estado == .enlaceInvalido { cambioEnNuevaContrasena(nuevaContrasena.estado) }
    }

    func cambioEnNuevaContrasena(_ estado: EstadoDeNuevaContrasena) {
        switch estado {
        case .enlaceInvalido where ruta.last == .nuevaContrasena: // R-6: solo desde Nueva contraseña, una vez
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

    /// C-02 · Ronda 2+3: el canje de un enlace ocurre una sola vez. Se comprueba antes de cualquier `await`, así que dos
    /// entregas seguidas de la misma URL no pueden pasar las dos.
    private func esNuevo(_ enlace: String, clase: ClaseDeEnlace) -> Bool {
        let nuevo = enlacesRecibidos.insert(enlace).inserted
        let url = URL(string: enlace)
        RegistroDeEnlaces.logger.notice("canje: enlace=\(clase.rawValue, privacy: .public) error=\(url.map(ClaseDeEnlace.traeError) ?? false, privacy: .public) canje=\(nuevo ? "nuevo" : "repetido", privacy: .public)")
        return nuevo
    }

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
