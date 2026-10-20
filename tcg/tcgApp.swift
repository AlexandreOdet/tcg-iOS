import SwiftUI

@main
struct tcgApp: App {
    @State private var viewModel: AuthViewModel

    init() {
        let client = APIClient(baseURL: AppConfig.apiBaseURL)
        let authAPI = LiveAuthAPI(client: client)
        let sessions = SessionManager(store: KeychainSessionStore(), api: authAPI)
        let userAPI = UserAPI(client: client, authorized: AuthorizedClient(sessions: sessions))
        _viewModel = State(initialValue: AuthViewModel(sessions: sessions, authAPI: authAPI, userAPI: userAPI))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
        }
    }
}
