import Foundation
import Observation

@Observable
final class AuthViewModel {
    enum State: Equatable {
        case launching
        case signedOut
        case signedIn(UserProfile)
        /// Session conservée mais serveur injoignable : on propose de réessayer sans déconnecter.
        case offline(String)
    }

    private(set) var state: State = .launching
    private(set) var isWorking = false
    private(set) var errorMessage: String?

    private let sessions: SessionManager
    private let authAPI: AuthAPI
    private let userAPI: UserAPI

    init(sessions: SessionManager, authAPI: AuthAPI, userAPI: UserAPI) {
        self.sessions = sessions
        self.authAPI = authAPI
        self.userAPI = userAPI
    }

    /// Au lancement : si une session existe, on la valide avec `GET /me`.
    func restore() async {
        guard await sessions.hasSession() else {
            state = .signedOut
            return
        }
        await loadProfile()
    }

    func signIn(identityToken: String, nonce: String) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let response = try await authAPI.signInWithApple(identityToken: identityToken, nonce: nonce)
            try await sessions.start(with: response)
            await loadProfile()
        } catch {
            errorMessage = Self.message(for: error)
            state = .signedOut
        }
    }

    func signOut() async {
        await sessions.signOut()
        state = .signedOut
    }

    func reportSignInFailure() {
        errorMessage = "La connexion avec Apple a échoué."
    }

    private func loadProfile() async {
        do {
            state = .signedIn(try await userAPI.me())
        } catch AuthError.signedOut {
            state = .signedOut
        } catch APIError.unauthorized {
            state = .signedOut
        } catch {
            state = .offline(Self.message(for: error))
        }
    }

    private static func message(for error: Error) -> String {
        switch error {
        case APIError.transport:
            return "Serveur injoignable. Vérifie ta connexion."
        case APIError.unauthorized:
            return "Connexion refusée."
        case APIError.server(let status, _, _):
            return "Erreur du serveur (\(status))."
        default:
            return "Une erreur est survenue."
        }
    }
}
