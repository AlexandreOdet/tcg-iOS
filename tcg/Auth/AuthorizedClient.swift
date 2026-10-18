import Foundation

/// Exécute un appel authentifié : un 401 déclenche UN rafraîchissement puis UN rejeu.
nonisolated struct AuthorizedClient: Sendable {
    let sessions: SessionManager

    func perform<T: Sendable>(_ call: @Sendable (_ accessToken: String) async throws -> T) async throws -> T {
        let session = try await sessions.currentSession()
        do {
            return try await call(session.accessToken)
        } catch APIError.unauthorized {
            let renewed = try await sessions.refreshed(after: session.accessToken)
            return try await call(renewed.accessToken)
        }
    }
}
