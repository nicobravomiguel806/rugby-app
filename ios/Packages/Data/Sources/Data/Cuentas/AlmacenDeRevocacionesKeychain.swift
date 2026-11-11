// C-02 · Almacén de las revocaciones pendientes (ADR 0010, AT-10, AT-17, CP-167h). Mismo Keychain que la sesión pero
// otro servicio (`<bundle>.revocaciones`), así que `borrarTodo()` de la sesión no lo toca. Una entrada por pendiente,
// con `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`: no viaja en respaldos ni a otro equipo.
import Foundation
import Security

/// Entradas por `id`. Lo implementan el Keychain (app) y un almacén en memoria (pruebas).
public protocol AlmacenDeRevocaciones: Sendable {
    func guardar(_ datos: Data, id: String) throws
    func leer(id: String) throws -> Data?
    func borrar(id: String) throws
    func ids() throws -> [String]
}

public final class AlmacenDeRevocacionesKeychain: AlmacenDeRevocaciones, @unchecked Sendable {
    private let servicio: String

    /// `servicio`: en la app es `<bundle id>.revocaciones`.
    public init(servicio: String) {
        self.servicio = servicio
    }

    private func consulta(_ id: String? = nil) -> [String: Any] {
        var consulta: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicio,
            kSecUseDataProtectionKeychain as String: true
        ]
        if let id { consulta[kSecAttrAccount as String] = id }
        return consulta
    }

    public func guardar(_ datos: Data, id: String) throws {
        let atributos: [String: Any] = [
            kSecValueData as String: datos,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        var estado = SecItemUpdate(consulta(id) as CFDictionary, atributos as CFDictionary)
        if estado == errSecItemNotFound {
            estado = SecItemAdd(consulta(id).merging(atributos) { _, nuevo in nuevo } as CFDictionary, nil)
        }
        guard estado == errSecSuccess else { throw ErrorDeKeychain(estado: estado) }
    }

    public func leer(id: String) throws -> Data? {
        var pedido = consulta(id)
        pedido[kSecReturnData as String] = true
        pedido[kSecMatchLimit as String] = kSecMatchLimitOne
        var resultado: AnyObject?
        let estado = SecItemCopyMatching(pedido as CFDictionary, &resultado)
        if estado == errSecItemNotFound { return nil }
        guard estado == errSecSuccess else { throw ErrorDeKeychain(estado: estado) }
        return resultado as? Data
    }

    public func borrar(id: String) throws {
        let estado = SecItemDelete(consulta(id) as CFDictionary)
        guard estado == errSecSuccess || estado == errSecItemNotFound else { throw ErrorDeKeychain(estado: estado) }
    }

    public func ids() throws -> [String] {
        var pedido = consulta()
        pedido[kSecReturnAttributes as String] = true
        pedido[kSecMatchLimit as String] = kSecMatchLimitAll
        var resultado: AnyObject?
        let estado = SecItemCopyMatching(pedido as CFDictionary, &resultado)
        if estado == errSecItemNotFound { return [] }
        guard estado == errSecSuccess else { throw ErrorDeKeychain(estado: estado) }
        return ((resultado as? [[String: Any]]) ?? []).compactMap { $0[kSecAttrAccount as String] as? String }
    }

    /// Solo para pruebas y diagnóstico: la accesibilidad con la que quedó guardada una entrada (CP-167h).
    public func accesibilidad(id: String) throws -> String? {
        var pedido = consulta(id)
        pedido[kSecReturnAttributes as String] = true
        pedido[kSecMatchLimit as String] = kSecMatchLimitOne
        var resultado: AnyObject?
        let estado = SecItemCopyMatching(pedido as CFDictionary, &resultado)
        if estado == errSecItemNotFound { return nil }
        guard estado == errSecSuccess else { throw ErrorDeKeychain(estado: estado) }
        return (resultado as? [String: Any])?[kSecAttrAccessible as String] as? String
    }
}
