# TCG Wiki (iOS)

App SwiftUI : cartes issues d'articles Wikipédia, boosters, collection. Serveur : [tcg-server](https://github.com/AlexandreOdet/tcg-server).

## Lancer en local

1. Serveur : dans `tcg-server`, `docker compose up -d`, copier `.env.example` vers `.env`, puis
   `APPLE_BUNDLE_ID=alexandreodet.tcg` (identique au bundle ID du projet) et un `JWT_SECRET` d'au moins
   32 caractères, puis `cargo run -p api`.
2. Xcode : target `tcg` > Signing & Capabilities > **+ Capability > Sign in with Apple**
   (compte Apple Developer requis).
3. Simulateur : `http://localhost:8080` fonctionne tel quel. Appareil réel : remplacer `localhost` dans
   `Config/AppConfig.swift` par l'IP du Mac **et** autoriser le HTTP local (Info > App Transport Security
   Settings > Allows Local Networking = YES).

## Structure

- `Config/` : URL du serveur.
- `Networking/` : client HTTP, erreurs, modèles.
- `Auth/` : nonce, Keychain, `SessionManager` (rafraîchissement unique), `AuthorizedClient` (401 → refresh → rejeu).
- `Features/` : écrans (connexion, profil provisoire).

Le dossier `tcg/` est synchronisé avec Xcode : tout fichier ajouté est dans la target automatiquement.
