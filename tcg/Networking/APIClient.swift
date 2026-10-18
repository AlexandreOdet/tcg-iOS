import Foundation

/// Client HTTP JSON bas niveau. Ne gère ni session ni rafraîchissement : voir `AuthorizedClient`.
nonisolated final class APIClient: Sendable {
    private let baseURL: URL
    private let urlSession: URLSession

    init(baseURL: URL, urlSession: URLSession = .shared) {
        self.baseURL = baseURL
        self.urlSession = urlSession
    }

    func send<T: Decodable>(
        _ method: String,
        _ path: String,
        body: (any Encodable & Sendable)? = nil,
        bearer: String? = nil,
        idempotencyKey: String? = nil
    ) async throws -> T {
        let data = try await perform(method, path, body: body, bearer: bearer, idempotencyKey: idempotencyKey)
        do {
            return try JSONCoding.decoder().decode(T.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }

    /// Pour les routes sans corps de réponse (204).
    func sendVoid(
        _ method: String,
        _ path: String,
        body: (any Encodable & Sendable)? = nil,
        bearer: String? = nil
    ) async throws {
        _ = try await perform(method, path, body: body, bearer: bearer, idempotencyKey: nil)
    }

    private func perform(
        _ method: String,
        _ path: String,
        body: (any Encodable & Sendable)?,
        bearer: String?,
        idempotencyKey: String?
    ) async throws -> Data {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = try JSONCoding.encoder().encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let bearer { request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization") }
        if let idempotencyKey { request.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key") }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw APIError.transport("Réponse non HTTP")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.from(status: http.statusCode, body: data)
        }
        return data
    }
}
