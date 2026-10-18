import Foundation

nonisolated enum AppConfig {
    /// Debug : serveur local. Sur un appareil réel, remplace `localhost` par l'IP de ton Mac
    /// (et autorise le HTTP local, voir README).
    static var apiBaseURL: URL {
        #if DEBUG
        URL(string: "http://localhost:8080")!
        #else
        URL(string: "https://api.example.com")! // À remplacer par l'URL de production.
        #endif
    }
}
