import SwiftUI
import GoogleSignIn
import Presentation

@main
struct RugbyAppApp: App {
    /// `static` + `@MainActor`: se crea una vez, en el hilo principal, y compila igual con el SDK de iOS 17
    /// (donde `App` todavía no está aislado al actor principal) que con los SDK nuevos.
    @MainActor private static let contenedor = ContenedorDeDependencias()
    @State private var mostrarCuenta = false

    var body: some Scene {
        WindowGroup {
            InicioView(viewModel: Self.contenedor.inicioViewModel())
                // SP-04 · P-6: botón «Cuenta» provisional que abre Acceso.
                .safeAreaInset(edge: .bottom) {
                    Button("Cuenta") { mostrarCuenta = true }
                        .buttonStyle(.borderedProminent)
                        .frame(minHeight: 44)
                        .padding()
                }
                .sheet(isPresented: $mostrarCuenta) {
                    NavigationStack { AccesoView(viewModel: Self.contenedor.accesoViewModel) }
                }
                // Regreso de la hoja de Google (esquema GOOGLE_IOS_URL_SCHEME en Info.plist).
                .onOpenURL { url in _ = GIDSignIn.sharedInstance.handle(url) }
        }
    }
}
