import Foundation

/// Routes d'authentification du serveur (voir docs/API.md côté serveur).
nonisolated protocol AuthAPI: Sendable {
    func signInWithApple(identityToken: String, nonce: String) async throws -> SessionResponse
    func refresh(_ refreshToken: String) async throws -> SessionResponse
    func logout(refreshToken: String) async throws
}

nonisolated struct LiveAuthAPI: AuthAPI {
    let client: APIClient

    private struct AppleBody: Encodable, Sendable { let identityToken: String; let nonce: String }
    private struct RefreshBody: Encodable, Sendable { let refreshToken: String }

    func signInWithApple(identityToken: String, nonce: String) async throws -> SessionResponse {
        try await client.send("POST", "auth/apple", body: AppleBody(identityToken: identityToken, nonce: nonce))
    }

    func refresh(_ refreshToken: String) async throws -> SessionResponse {
        try await client.send("POST", "auth/refresh", body: RefreshBody(refreshToken: refreshToken))
    }

    func logout(refreshToken: String) async throws {
        try await client.sendVoid("POST", "auth/logout", body: RefreshBody(refreshToken: refreshToken))
    }
}
