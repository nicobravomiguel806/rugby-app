import SwiftUI

/// C-02 · Campo de contraseña con «Mostrar/Ocultar» (como Registro, P-8), con objetivos de 44 pt (RNF-08).
struct CampoDeContrasena: View {
    let titulo: String
    @Binding var texto: String
    let mostrar: Bool
    let alternar: () -> Void
    let identificador: String
    var esNueva = false

    var body: some View {
        HStack {
            Group {
                if mostrar {
                    TextField(titulo, text: $texto)
                } else {
                    SecureField(titulo, text: $texto)
                }
            }
            .textContentType(esNueva ? .newPassword : .password)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .accessibilityIdentifier(identificador)
            Button(mostrar ? "Ocultar" : "Mostrar", action: alternar)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityIdentifier("\(identificador).mostrar")
        }
    }
}

/// Recuadro con borde rojo si hay error y el mensaje debajo.
struct CampoConMarco<Contenido: View>: View {
    let titulo: String
    let error: String?
    @ViewBuilder let contenido: () -> Contenido

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            contenido()
                .padding(10)
                .frame(minHeight: 44)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(error == nil ? Color.secondary.opacity(0.4) : Color.red))
                .accessibilityLabel(titulo)
            if let error {
                Text(error).font(.footnote).foregroundStyle(.red)
            }
        }
    }
}
