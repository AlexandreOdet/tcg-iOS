import Foundation
import Security

nonisolated protocol SessionStore: Sendable {
    func load() throws -> Session?
    func save(_ session: Session) throws
    func clear() throws
}

nonisolated struct KeychainError: Error, Equatable { let status: OSStatus }

/// Jetons dans le Keychain, lisibles après le premier déverrouillage (rafraîchissement en
/// arrière-plan possible) et jamais migrés vers un autre appareil.
nonisolated struct KeychainSessionStore: SessionStore {
    var service = "tcg.session"
    var account = "default"

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    func load() throws -> Session? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else { throw KeychainError(status: status) }
        return try JSONDecoder().decode(Session.self, from: data)
    }

    func save(_ session: Session) throws {
        let data = try JSONEncoder().encode(session)
        let update = SecItemUpdate(baseQuery as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if update == errSecSuccess { return }
        guard update == errSecItemNotFound else { throw KeychainError(status: update) }

        var add = baseQuery
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }

    func clear() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError(status: status) }
    }
}
