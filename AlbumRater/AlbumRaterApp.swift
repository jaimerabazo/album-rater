import SwiftUI

@main
struct AlbumRaterApp: App {
    @State private var auth = AuthStore(client: Backend.makeClient())

    var body: some Scene {
        WindowGroup {
            Group {
                if auth.client == nil {
                    ContentUnavailableView(
                        "Connect your backend",
                        systemImage: "externaldrive.badge.person.crop",
                        description: Text("Follow the README to add your Supabase project configuration, then run the app again.")
                    )
                } else if auth.isRestoring {
                    ProgressView("Restoring your account…")
                } else if let user = auth.user, let client = auth.client, !auth.isRecovering {
                    // Una cuenta distinta obtiene su propio estado; no reutiliza el perfil anterior.
                    ProfileView(user: user, auth: auth, client: client)
                        .id(user.id)
                } else {
                    AuthView(auth: auth)
                }
            }
            .task { await auth.observeSession() }
        }
    }
}
