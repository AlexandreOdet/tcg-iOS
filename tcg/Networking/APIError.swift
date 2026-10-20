import Foundation

nonisolated enum APIError: Error, Equatable {
    /// 401 : jeton absent, expiré ou révoqué.
    case unauthorized
    /// Autre statut HTTP d'erreur. `code` et `message` viennent du corps `{ "error": … }` s'il existe.
    case server(status: Int, code: String?, message: String?)
    /// Réseau indisponible, délai dépassé…
    case transport(String)
    case decoding(String)

    /// Construit l'erreur d'une réponse HTTP. Ne suppose JAMAIS que le corps est du JSON :
    /// le framework serveur renvoie du texte brut pour un JSON mal formé.
    static func from(status: Int, body: Data) -> APIError {
        struct Envelope: Decodable {
            struct Inner: Decodable { let code: String?; let message: String? }
            let error: Inner
        }
        let parsed = try? JSONDecoder().decode(Envelope.self, from: body)
        if status == 401 { return .unauthorized }
        return .server(status: status, code: parsed?.error.code, message: parsed?.error.message)
    }
}

/// Erreurs de session côté app.
nonisolated enum AuthError: Error, Equatable {
    /// Plus de session valide : il faut repasser par Sign in with Apple.
    case signedOut
}
