import Foundation
import Testing
@testable import tcg

// MARK: - Doubles de test

nonisolated final class MemoryStore: SessionStore, @unchecked Sendable {
    private let lock = NSLock()
    private var session: Session?

    init(_ session: Session? = nil) { self.session = session }

    func load() throws -> Session? { lock.withLock { session } }
    func save(_ session: Session) throws { lock.withLock { self.session = session } }
    func clear() throws { lock.withLock { session = nil } }
}

actor FakeAuthAPI: AuthAPI {
    private(set) var refreshCalls = 0
    private(set) var logoutCalls = 0
    var refreshResult: Result<SessionResponse, APIError>
    var delay: Duration

    init(refreshResult: Result<SessionResponse, APIError> = .success(.renewed), delay: Duration = .milliseconds(100)) {
        self.refreshResult = refreshResult
        self.delay = delay
    }

    func signInWithApple(identityToken: String, nonce: String) async throws -> SessionResponse {
        .renewed
    }

    func refresh(_ refreshToken: String) async throws -> SessionResponse {
        refreshCalls += 1
        try await Task.sleep(for: delay) // laisse les appels concurrents se chevaucher
        return try refreshResult.get()
    }

    func logout(refreshToken: String) async throws { logoutCalls += 1 }
}

extension SessionResponse {
    nonisolated static let renewed = SessionResponse(
        accessToken: "new", refreshToken: "r2", tokenType: "Bearer", expiresIn: 900, isNewUser: false)
}

extension Session {
    nonisolated static let old = Session(accessToken: "old", refreshToken: "r1")
}

// MARK: - SessionManager

struct SessionManagerTests {
    @Test func concurrentRefreshesCallTheServerOnlyOnce() async throws {
        let store = MemoryStore(.old)
        let api = FakeAuthAPI()
        let manager = SessionManager(store: store, api: api)

        let tokens = try await withThrowingTaskGroup(of: String.self) { group in
            for _ in 0..<10 {
                group.addTask { try await manager.refreshed(after: "old").accessToken }
            }
            var results: [String] = []
            for try await token in group { results.append(token) }
            return results
        }

        #expect(tokens.count == 10)
        #expect(Set(tokens) == ["new"])
        #expect(await api.refreshCalls == 1)
        #expect(try store.load() == Session(accessToken: "new", refreshToken: "r2"))
    }

    @Test func aCallerWithAStaleTokenReusesTheCurrentSession() async throws {
        let store = MemoryStore(Session(accessToken: "new", refreshToken: "r2"))
        let api = FakeAuthAPI()
        let manager = SessionManager(store: store, api: api)

        let session = try await manager.refreshed(after: "old")

        #expect(session.accessToken == "new")
        #expect(await api.refreshCalls == 0)
    }

    @Test func anUnauthorizedRefreshEndsTheSession() async throws {
        let store = MemoryStore(.old)
        let api = FakeAuthAPI(refreshResult: .failure(.unauthorized), delay: .zero)
        let manager = SessionManager(store: store, api: api)

        await #expect(throws: AuthError.signedOut) {
            try await manager.refreshed(after: "old")
        }
        #expect(try store.load() == nil)
    }

    @Test func aNetworkErrorKeepsTheSession() async throws {
        let store = MemoryStore(.old)
        let api = FakeAuthAPI(refreshResult: .failure(.transport("hors ligne")), delay: .zero)
        let manager = SessionManager(store: store, api: api)

        await #expect(throws: APIError.transport("hors ligne")) {
            try await manager.refreshed(after: "old")
        }
        #expect(try store.load() == .old)
    }

    @Test func signOutRevokesOnTheServerAndClearsLocally() async throws {
        let store = MemoryStore(.old)
        let api = FakeAuthAPI()
        let manager = SessionManager(store: store, api: api)

        await manager.signOut()

        #expect(await api.logoutCalls == 1)
        #expect(try store.load() == nil)
        #expect(await manager.hasSession() == false)
    }
}

// MARK: - AuthorizedClient

struct AuthorizedClientTests {
    @Test func a401TriggersOneRefreshAndOneReplay() async throws {
        let api = FakeAuthAPI(delay: .zero)
        let manager = SessionManager(store: MemoryStore(.old), api: api)
        let client = AuthorizedClient(sessions: manager)

        let used: String = try await client.perform { token in
            if token == "old" { throw APIError.unauthorized }
            return token
        }

        #expect(used == "new")
        #expect(await api.refreshCalls == 1)
    }

    @Test func aSecond401AfterTheReplayIsNotRetriedAgain() async throws {
        let api = FakeAuthAPI(delay: .zero)
        let manager = SessionManager(store: MemoryStore(.old), api: api)
        let client = AuthorizedClient(sessions: manager)

        await #expect(throws: APIError.unauthorized) {
            let _: String = try await client.perform { _ in throw APIError.unauthorized }
        }
        #expect(await api.refreshCalls == 1)
    }

    @Test func withoutASessionTheCallIsRefusedBeforeAnyRequest() async throws {
        let manager = SessionManager(store: MemoryStore(nil), api: FakeAuthAPI())
        let client = AuthorizedClient(sessions: manager)

        await #expect(throws: AuthError.signedOut) {
            let _: String = try await client.perform { _ in "jamais appelé" }
        }
    }
}

// MARK: - Erreurs HTTP, JSON, nonce

struct NetworkingTests {
    @Test func a401IsUnauthorized() {
        #expect(APIError.from(status: 401, body: Data()) == .unauthorized)
    }

    @Test func parsesTheServerErrorEnvelope() {
        let body = Data(#"{"error":{"code":"conflict","message":"aucun booster disponible"}}"#.utf8)
        #expect(APIError.from(status: 409, body: body)
            == .server(status: 409, code: "conflict", message: "aucun booster disponible"))
    }

    @Test func plainTextBodiesDoNotBreakErrorHandling() {
        let body = Data("Failed to parse the request body as JSON".utf8)
        #expect(APIError.from(status: 422, body: body) == .server(status: 422, code: nil, message: nil))
    }

    @Test func decodesASessionResponse() throws {
        let json = Data(#"""
        {"access_token":"a","refresh_token":"r","token_type":"Bearer","expires_in":900,"is_new_user":true}
        """#.utf8)
        let response = try JSONCoding.decoder().decode(SessionResponse.self, from: json)
        #expect(response.accessToken == "a" && response.refreshToken == "r")
        #expect(response.expiresIn == 900 && response.isNewUser)
    }

    @Test func decodesProfileDatesWithAndWithoutFractionalSeconds() throws {
        let id = "8f0c2a55-1f6f-4a53-9d8e-6c1b5f0b1f10"
        for date in ["2026-10-18T15:19:13.563255Z", "2026-10-18T15:19:13Z"] {
            let json = Data(#"{"id":"\#(id)","pseudo":null,"created_at":"\#(date)"}"#.utf8)
            let profile = try JSONCoding.decoder().decode(UserProfile.self, from: json)
            #expect(profile.pseudo == nil)
            #expect(profile.id == UUID(uuidString: id))
        }
    }

    @Test func nonceHashMatchesTheKnownSHA256Vector() {
        #expect(Nonce.sha256Hex("abc")
            == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    @Test func randomNonceIsHexAndUnique() {
        let a = Nonce.random()
        let b = Nonce.random()
        #expect(a.count == 64 && a.allSatisfy(\.isHexDigit))
        #expect(a != b)
    }
}
