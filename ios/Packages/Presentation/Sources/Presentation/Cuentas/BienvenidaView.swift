import SwiftUI

/// C-01 · Bienvenida (Figma paso 1). Espejo en Android: presentation/.../cuentas/BienvenidaScreen.kt.
public struct BienvenidaView: View {
    private let crearCuenta: () -> Void
    private let yaTengoCuenta: () -> Void

    public init(crearCuenta: @escaping () -> Void, yaTengoCuenta: @escaping () -> Void) {
        self.crearCuenta = crearCuenta
        self.yaTengoCuenta = yaTengoCuenta
    }

    public var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("Tu torneo de rugby, en una app")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Spacer()
            Button(action: crearCuenta) { Text("Crear cuenta").frame(maxWidth: .infinity, minHeight: 44) }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("bienvenida.crearCuenta")
            Button(action: yaTengoCuenta) { Text("Ya tengo cuenta").frame(maxWidth: .infinity, minHeight: 44) }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("bienvenida.yaTengoCuenta")
        }
        .padding()
        .navigationTitle("Bienvenida")
        .navigationBarTitleDisplayMode(.inline)
    }
}
