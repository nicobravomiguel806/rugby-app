// C-01 · Lo que la persona escribe en el formulario de registro con correo. Espejo en Android: domain/.../cuentas/DatosDeRegistro.kt.
// La descripción nunca incluye la contraseña (SP-04 H-7).

public struct DatosDeRegistro: Equatable, Sendable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    public let nombreCompleto: String
    public let correo: String
    public let contrasena: String
    public let aceptoAvisoDePrivacidad: Bool
    /// Finalidades secundarias marcadas. Vacío por defecto: las tres casillas desmarcadas (A-1).
    public let finalidadesAceptadas: Set<FinalidadSecundaria>

    public init(
        nombreCompleto: String,
        correo: String,
        contrasena: String,
        aceptoAvisoDePrivacidad: Bool,
        finalidadesAceptadas: Set<FinalidadSecundaria> = []
    ) {
        self.nombreCompleto = nombreCompleto
        self.correo = correo
        self.contrasena = contrasena
        self.aceptoAvisoDePrivacidad = aceptoAvisoDePrivacidad
        self.finalidadesAceptadas = finalidadesAceptadas
    }

    public var description: String {
        "DatosDeRegistro(nombreCompleto: \(nombreCompleto), correo: \(correo), contrasena: ***, "
            + "aceptoAvisoDePrivacidad: \(aceptoAvisoDePrivacidad), finalidadesAceptadas: \(finalidadesAceptadas.map(\.rawValue).sorted()))"
    }

    public var debugDescription: String { description }

    public var customMirror: Mirror {
        Mirror(self, children: [
            "nombreCompleto": nombreCompleto,
            "correo": correo,
            "contrasena": "***",
            "aceptoAvisoDePrivacidad": aceptoAvisoDePrivacidad,
            "finalidadesAceptadas": finalidadesAceptadas
        ])
    }
}
