import SwiftUI
import Presentation

@main
struct RugbyAppApp: App {
    private let contenedor = ContenedorDeDependencias()

    var body: some Scene {
        WindowGroup {
            InicioView(viewModel: contenedor.inicioViewModel())
        }
    }
}
