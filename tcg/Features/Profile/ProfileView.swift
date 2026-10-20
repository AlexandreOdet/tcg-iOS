import SwiftUI

/// Écran provisoire : valide toute la chaîne (connexion, Keychain, `GET /me`).
/// Il sera remplacé par l'accueil (boosters) et la collection.
struct ProfileView: View {
    let profile: UserProfile
    let viewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            List {
                LabeledContent("Identifiant", value: profile.id.uuidString)
                LabeledContent("Pseudo", value: profile.pseudo ?? "—")
                LabeledContent("Inscrit le", value: profile.createdAt.formatted(date: .abbreviated, time: .shortened))
                Section {
                    Button("Se déconnecter", role: .destructive) {
                        Task { await viewModel.signOut() }
                    }
                }
            }
            .navigationTitle("Profil")
        }
    }
}
