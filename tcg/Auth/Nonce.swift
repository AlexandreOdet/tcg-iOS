import CryptoKit
import Foundation
import Security

/// Nonce de Sign in with Apple : on envoie à Apple le SHA-256 (hex minuscule) et au serveur le nonce brut.
nonisolated enum Nonce {
    static func random(byteCount: Int = 32) -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        let status = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
        precondition(status == errSecSuccess, "Génération aléatoire impossible")
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    static func sha256Hex(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
