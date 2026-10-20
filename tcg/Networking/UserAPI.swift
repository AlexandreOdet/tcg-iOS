import Foundation

nonisolated struct UserAPI: Sendable {
    let client: APIClient
    let authorized: AuthorizedClient

    func me() async throws -> UserProfile {
        try await authorized.perform { token in
            try await client.send("GET", "me", bearer: token)
        }
    }
}
