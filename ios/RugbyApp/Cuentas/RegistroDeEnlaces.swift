import Foundation
import os
import Data

/// C-02 · Ronda 2+3 (PO 2026-11-17). Por dónde llegó una URL a la app.
enum CaminoDelEnlace: String {
    case onOpenURL, connectionOptions, onAppear, presentacion
}

/// Qué enlace es (ADR 0008): del correo de verificación, del de recuperación u otro (el regreso de Google).
enum ClaseDeEnlace: String {
    case verificacion, recuperacion, otro

    init(_ url: URL) {
        if ClienteSupabase.esEnlaceDeVerificacion(url) {
            self = .verificacion
        } else if ClienteSupabase.esEnlaceDeRecuperacion(url) {
            self = .recuperacion
        } else {
            self = .otro
        }
    }

    /// Si el enlace trae `error` o `error_code` en la query o en el fragmento. Solo se registra el sí/no.
    static func traeError(_ url: URL) -> Bool {
        let partes = [URLComponents(url: url, resolvingAgainstBaseURL: false)?.query, url.fragment].compactMap { $0 }
        return partes.contains { parte in
            parte.split(separator: "&").contains { $0.hasPrefix("error=") || $0.hasPrefix("error_code=") }
        }
    }
}

/// Registros de diagnóstico del camino de los enlaces (`.notice`, para que queden en el logarchive del `.xcresult`).
/// NUNCA se registra la URL, su query, el `code`, ningún token ni ningún correo: solo enums, bools y la fase de la escena.
enum RegistroDeEnlaces {
    static let logger = Logger(subsystem: "mx.rugbyapp", category: "enlaces")
}
