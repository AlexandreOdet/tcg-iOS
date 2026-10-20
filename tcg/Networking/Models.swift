import Foundation

/// Jetons conservés dans le Keychain.
nonisolated struct Session: Codable, Equatable, Sendable {
    var accessToken: String
    var refreshToken: String
}

/// Réponse de `/auth/apple` et `/auth/refresh`.
nonisolated struct SessionResponse: Decodable, Equatable, Sendable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresIn: Int
    let isNewUser: Bool

    var session: Session { Session(accessToken: accessToken, refreshToken: refreshToken) }
}

/// Réponse de `GET /me`.
nonisolated struct UserProfile: Decodable, Equatable, Sendable {
    let id: UUID
    let pseudo: String?
    let createdAt: Date
}

nonisolated enum JSONCoding {
    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            // Le serveur renvoie des dates RFC 3339, avec ou sans fractions de seconde.
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: string) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: string) { return date }
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Date illisible : \(string)")
        }
        return decoder
    }

    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }
}
