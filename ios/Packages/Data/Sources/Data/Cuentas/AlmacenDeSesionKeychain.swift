// SP-04 · Almacén seguro de la sesión de Supabase en iOS (RNF-12, AT-10, CA-1). Implementa AuthLocalStorage, así
// que supabase-swift guarda la sesión aquí y nunca en UserDefaults. Keychain con
// kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly: no viaja en respaldos ni a otro equipo (AT-17).
import Foundation
import Security
import Auth

/// Almacén que, además de lo que pide supabase-swift, sabe borrar todo lo suyo (cierre de sesión, P-8).
public protocol AlmacenSeguroDeSesion: AuthLocalStorage {
    func borrarTodo() throws
}

public struct ErrorDeKeychain: Error, Equatable {
    public let estado: OSStatus
}

public final class AlmacenDeSesionKeychain: AlmacenSeguroDeSesion {
    private let servicio: String

    /// `servicio`: en la app es `<bundle id>.sesion`.
    public init(servicio: String) {
        self.servicio = servicio
    }

    private func consulta(_ clave: String? = nil) -> [String: Any] {
        var consulta: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicio,
            kSecUseDataProtectionKeychain as String: true
        ]
        if let clave { consulta[kSecAttrAccount as String] = clave }
        return consulta
    }

    public func store(key: String, value: Data) throws {
        let atributos: [String: Any] = [
            kSecValueData as String: value,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        var estado = SecItemUpdate(consulta(key) as CFDictionary, atributos as CFDictionary)
        if estado == errSecItemNotFound {
            estado = SecItemAdd(consulta(key).merging(atributos) { _, nuevo in nuevo } as CFDictionary, nil)
        }
        guard estado == errSecSuccess else { throw ErrorDeKeychain(estado: estado) }
    }

    public func retrieve(key: String) throws -> Data? {
        var pedido = consulta(key)
        pedido[kSecReturnData as String] = true
        pedido[kSecMatchLimit as String] = kSecMatchLimitOne
        var resultado: AnyObject?
        let estado = SecItemCopyMatching(pedido as CFDictionary, &resultado)
        if estado == errSecItemNotFound { return nil }
        guard estado == errSecSuccess else { throw ErrorDeKeychain(estado: estado) }
        return resultado as? Data
    }

    public func remove(key: String) throws {
        try borrar(consulta(key))
    }

    public func borrarTodo() throws {
        try borrar(consulta())
    }

    private func borrar(_ consulta: [String: Any]) throws {
        let estado = SecItemDelete(consulta as CFDictionary)
        guard estado == errSecSuccess || estado == errSecItemNotFound else { throw ErrorDeKeychain(estado: estado) }
    }
}
