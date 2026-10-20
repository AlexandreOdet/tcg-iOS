import AuthenticationServices
import SwiftUI

struct SignInView: View {
    let viewModel: AuthViewModel
    /// Nonce brut : reste en mémoire le temps de la demande, jamais envoyé à Apple.
    @State private var rawNonce = ""

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("TCG Wiki")
                .font(.largeTitle.bold())
            Text("Collectionne les articles de Wikipédia.")
                .foregroundStyle(.secondary)
            Spacer()

            if let message = viewModel.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            SignInWithAppleButton(.signIn) { request in
                rawNonce = Nonce.random()
                request.requestedScopes = [.email]          // le pseudo sera choisi dans l'app
                request.nonce = Nonce.sha256Hex(rawNonce)   // jamais le nonce brut
            } onCompletion: { result in
                handle(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .disabled(viewModel.isWorking)
        }
        .padding(24)
        .overlay { if viewModel.isWorking { ProgressView() } }
    }

    private func handle(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let identityToken = String(data: tokenData, encoding: .utf8)
            else { return }
            let nonce = rawNonce
            Task { await viewModel.signIn(identityToken: identityToken, nonce: nonce) }
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            viewModel.reportSignInFailure()
        }
    }
}
