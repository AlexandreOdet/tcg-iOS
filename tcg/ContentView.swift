import SwiftUI

struct ContentView: View {
    let viewModel: AuthViewModel

    var body: some View {
        Group {
            switch viewModel.state {
            case .launching:
                ProgressView()
            case .signedOut:
                SignInView(viewModel: viewModel)
            case .signedIn(let profile):
                ProfileView(profile: profile, viewModel: viewModel)
            case .offline(let message):
                ContentUnavailableView {
                    Label("Hors ligne", systemImage: "wifi.slash")
                } description: {
                    Text(message)
                } actions: {
                    Button("Réessayer") { Task { await viewModel.restore() } }
                }
            }
        }
        .task { await viewModel.restore() }
    }
}
