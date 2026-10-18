import Foundation

/// Source unique de vérité pour la session.
///
/// Le refresh token du serveur est **à usage unique** et le rejouer (au-delà de 10 s) révoque toute
/// la session : il ne doit donc jamais y avoir deux `/auth/refresh` en parallèle. Cet acteur
/// sérialise les rafraîchissements (« single-flight »).
actor SessionManager {
    private let store: SessionStore
    private let api: AuthAPI
    private var refreshTask: Task<Session, Error>?

    init(store: SessionStore, api: AuthAPI) {
        self.store = store
        self.api = api
    }

    func hasSession() -> Bool {
        (try? store.load()) != nil
    }

    func currentSession() throws -> Session {
        guard let session = try store.load() else { throw AuthError.signedOut }
        return session
    }

    /// Enregistre la session obtenue après une connexion.
    func start(with response: SessionResponse) throws {
        try store.save(response.session)
    }

    /// À appeler quand une requête a reçu un 401 avec `failedAccessToken`.
    func refreshed(after failedAccessToken: String) async throws -> Session {
        // Un autre appel a déjà rafraîchi pendant qu'on attendait : on réutilise son résultat.
        if let current = try store.load(), current.accessToken != failedAccessToken {
            return current
        }
        if let task = refreshTask { return try await task.value }

        let store = self.store
        let api = self.api
        let task = Task<Session, Error> {
            guard let current = try store.load() else { throw AuthError.signedOut }
            let renewed = try await api.refresh(current.refreshToken).session
            // Écrit AVANT de rejouer quoi que ce soit : l'ancien jeton est déjà consommé.
            try store.save(renewed)
            return renewed
        }
        refreshTask = task
        defer { refreshTask = nil }
        do {
            return try await task.value
        } catch APIError.unauthorized {
            // 401 sur /auth/refresh : session terminée, pas de nouvelle tentative.
            try? store.clear()
            throw AuthError.signedOut
        }
    }

    /// Déconnexion : révocation côté serveur au mieux, effacement local garanti.
    func signOut() async {
        if let session = try? store.load() {
            try? await api.logout(refreshToken: session.refreshToken)
        }
        try? store.clear()
    }
}
