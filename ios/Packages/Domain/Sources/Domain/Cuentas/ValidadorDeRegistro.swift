// C-01 · Reglas de «Datos del registro con correo» (domain-model.md §1, P-8). Puras: sin Foundation.
// Las longitudes se cuentan en puntos de código Unicode para dar lo mismo en Swift y en Kotlin.
// Espejo en Android: domain/.../cuentas/ValidadorDeRegistro.kt.

public struct ValidadorDeRegistro: Sendable {
    public static let longitudMinimaDelNombre = 2
    public static let longitudMaximaDelNombre = 120
    public static let longitudMinimaDeLaContrasena = 10

    public init() {}

    /// Todos los errores a la vez, en orden: nombre, correo, contraseña, aviso. Vacío si los datos son válidos.
    public func validar(_ datos: DatosDeRegistro) -> [ErrorDeRegistro] {
        var errores: [ErrorDeRegistro] = []
        let nombre = Self.recortar(datos.nombreCompleto).unicodeScalars.count
        if nombre < Self.longitudMinimaDelNombre || nombre > Self.longitudMaximaDelNombre { errores.append(.nombreInvalido) }
        if !Self.esCorreoValido(Self.normalizarCorreo(datos.correo)) { errores.append(.correoInvalido) }
        if datos.contrasena.unicodeScalars.count < Self.longitudMinimaDeLaContrasena { errores.append(.contrasenaCorta) }
        if !datos.aceptoAvisoDePrivacidad { errores.append(.avisoNoAceptado) }
        return errores
    }

    /// Nombre sin espacios al inicio y al final; correo además en minúsculas. La contraseña no se toca.
    public func normalizar(_ datos: DatosDeRegistro) -> DatosDeRegistro {
        DatosDeRegistro(
            nombreCompleto: Self.recortar(datos.nombreCompleto),
            correo: Self.normalizarCorreo(datos.correo),
            contrasena: datos.contrasena,
            aceptoAvisoDePrivacidad: datos.aceptoAvisoDePrivacidad,
            finalidadesAceptadas: datos.finalidadesAceptadas
        )
    }

    static func normalizarCorreo(_ correo: String) -> String {
        recortar(correo).lowercased()
    }

    static func recortar(_ texto: String) -> String {
        let escalares = texto.unicodeScalars
        guard let inicio = escalares.firstIndex(where: { !$0.properties.isWhitespace }),
              let fin = escalares.lastIndex(where: { !$0.properties.isWhitespace }) else { return "" }
        return String(escalares[inicio...fin])
    }

    /// Formato `algo@dominio.tld`: una sola `@`, sin espacios, parte local no vacía y un dominio con al menos
    /// dos etiquetas no vacías separadas por puntos.
    static func esCorreoValido(_ correo: String) -> Bool {
        guard !correo.unicodeScalars.contains(where: { $0.properties.isWhitespace }) else { return false }
        let partes = correo.split(separator: "@", omittingEmptySubsequences: false)
        guard partes.count == 2, !partes[0].isEmpty else { return false }
        let etiquetas = partes[1].split(separator: ".", omittingEmptySubsequences: false)
        return etiquetas.count >= 2 && etiquetas.allSatisfy { !$0.isEmpty }
    }
}
