import SwiftUI
import Domain

/// T-03 · Pantalla Inicio provisional (P-2): título «Rugby App» y la lista de modalidades.
/// La pantalla definitiva llega con C-08. Espejo en Android: presentation/.../inicio/InicioScreen.kt.
public struct InicioView: View {
    @State private var viewModel: InicioViewModel

    public init(viewModel: InicioViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        NavigationStack {
            List(viewModel.modalidades, id: \.modalidad) { reglas in
                Text(Self.nombre(de: reglas.modalidad))
            }
            .navigationTitle("Rugby App")
        }
        .onAppear { viewModel.cargar() }
    }

    /// Texto visible de cada modalidad. Es presentación, no regla de negocio.
    static func nombre(de modalidad: Modalidad) -> String {
        switch modalidad {
        case .fifteens: return "XV"
        case .tens: return "10s"
        case .sevens: return "7s"
        case .league13: return "Rugby 13"
        case .festival: return "Festival"
        }
    }
}
