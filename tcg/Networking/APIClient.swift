import Alamofire
import Foundation

/// Low-level JSON HTTP client built on Alamofire. It knows nothing about sessions or token
/// refresh: see `AuthorizedClient`.
nonisolated final class APIClient: Sendable {
    private let baseURL: URL
    private let session: Session

    /// - Parameter session: Alamofire session; inject a custom one in tests (e.g. with a stub URLProtocol).
    init(baseURL: URL, session: Session = .default) {
        self.baseURL = baseURL
        self.session = session
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

    /// For routes without a response body (204).
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
        request.method = HTTPMethod(rawValue: method)
        request.headers.add(.accept("application/json"))
        if let body {
            // Encoded here (not by Alamofire) to share the snake_case encoder with the rest of the app.
            request.httpBody = try JSONCoding.encoder().encode(body)
            request.headers.add(.contentType("application/json"))
        }
        if let bearer { request.headers.add(.authorization(bearerToken: bearer)) }
        if let idempotencyKey { request.headers.add(name: "Idempotency-Key", value: idempotencyKey) }

        // No `validate()`: we map status codes ourselves to keep the server's error envelope.
        // `serializingData` accepts empty bodies for 204/205.
        let response = await session.request(request).serializingData().response
        guard let http = response.response else {
            throw APIError.transport(response.error?.localizedDescription ?? "No response")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.from(status: http.statusCode, body: response.data ?? Data())
        }
        return response.data ?? Data()
    }
}
