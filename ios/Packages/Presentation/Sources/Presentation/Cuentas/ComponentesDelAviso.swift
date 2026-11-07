import SwiftUI
import SafariServices
import Domain

/// C-01 · Piezas compartidas por Registro y Aviso de privacidad: la casilla obligatoria con su enlace y las tres
/// casillas opcionales, separadas y desmarcadas por defecto (A-1). Espejo en Android: presentation/.../cuentas/ComponentesDelAviso.kt.
struct CasillaDelAviso: View {
    @Binding var acepto: Bool
    let urlDelAviso: URL?
    @State private var mostrarAviso = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(isOn: $acepto) { Text("Acepto el Aviso de Privacidad (LFPDPPP)") }
                .toggleStyle(.casilla)
                .accessibilityIdentifier("aviso.obligatorio")
            if let urlDelAviso {
                Button("Leer el Aviso de Privacidad") { mostrarAviso = true }
                    .frame(minHeight: 44)
                    .sheet(isPresented: $mostrarAviso) { VistaSafari(url: urlDelAviso).ignoresSafeArea() }
                    .accessibilityIdentifier("aviso.enlace")
            } else {
                // Configuración pendiente (P-5): la URL pública del aviso todavía no existe.
                Text("Aviso de Privacidad (\(AvisoDePrivacidad.versionVigente))")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("aviso.enlace")
            }
        }
    }
}

struct CasillasDeFinalidades: View {
    let marcadas: Set<FinalidadSecundaria>
    let alternar: (FinalidadSecundaria) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Finalidades opcionales: puedes negarte a cada una y seguir usando la app")
                .font(.footnote)
                .foregroundStyle(.secondary)
            ForEach(FinalidadSecundaria.allCases, id: \.self) { finalidad in
                Toggle(isOn: Binding(get: { marcadas.contains(finalidad) }, set: { _ in alternar(finalidad) })) {
                    Text(Self.texto(de: finalidad))
                }
                .toggleStyle(.casilla)
                .accessibilityIdentifier("finalidad.\(finalidad.rawValue)")
            }
        }
    }

    /// Texto visible de cada finalidad. Es presentación, no regla de negocio.
    static func texto(de finalidad: FinalidadSecundaria) -> String {
        switch finalidad {
        case .notificaciones: return "Notificaciones de lo que sigo"
        case .comunicaciones: return "Comunicaciones de las ligas o de la Asociación"
        case .estadisticas: return "Estadísticas anónimas"
        }
    }
}

/// Casilla cuadrada con área táctil de 44 pt o más (RNF-08).
struct EstiloDeCasilla: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .foregroundStyle(configuration.isOn ? Color.accentColor : Color.secondary)
                configuration.label
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

extension ToggleStyle where Self == EstiloDeCasilla {
    static var casilla: EstiloDeCasilla { EstiloDeCasilla() }
}

/// SFSafariViewController para leer el aviso sin salir de la app.
struct VistaSafari: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url: url) }
    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

/// Textos visibles de los errores de C-01. Son presentación, no reglas de negocio.
enum TextosDeCuenta {
    /// Mensaje neutro tras crear la cuenta, igual para un correo nuevo y uno con cuenta (P-7, AT-11, CP-011).
    static let mensajeNeutro = "Si este correo no tenía cuenta, te enviamos un enlace para activarla. Si ya tienes cuenta, inicia sesión."

    static func mensaje(de error: ErrorDeRegistro) -> String {
        switch error {
        case .nombreInvalido: return "Escribe tu nombre completo (de 2 a 120 caracteres)"
        case .correoInvalido: return "Escribe un correo válido, como nombre@dominio.mx"
        case .contrasenaCorta: return "La contraseña debe tener al menos 10 caracteres"
        case .avisoNoAceptado: return "Para crear tu cuenta, acepta el Aviso de Privacidad"
        case .enlaceInvalido: return "Abre el enlace en este teléfono o pide uno nuevo"
        case .demasiadosIntentos: return "Demasiados intentos. Espera unos minutos e inténtalo de nuevo"
        case .sinConexion: return "Sin conexión. Inténtalo de nuevo"
        case .desconocido: return "Algo salió mal. Inténtalo de nuevo"
        }
    }

    static func mensaje(de error: ErrorDeConsentimiento) -> String {
        switch error {
        case .versionDesactualizada: return "El Aviso de Privacidad cambió. Actualiza la app para aceptarlo"
        case .sinSesion: return "Tu sesión terminó. Vuelve a entrar"
        case .sinConexion: return "Sin conexión. Inténtalo de nuevo"
        case .desconocido: return "Algo salió mal. Inténtalo de nuevo"
        }
    }
}
