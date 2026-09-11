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
                } else if let user = auth.user, !auth.isRecovering {
                    NavigationStack {
                        List {
                            Section("Your account") {
                                Text(user.email ?? "Signed in")
                            }
                            Section {
                                ContentUnavailableView(
                                    "Your listening history starts here",
                                    systemImage: "opticaldisc",
                                    description: Text("Album sessions, track ratings, and friends are the next step.")
                                )
                            }
                            Section {
                                Button("Sign out", role: .destructive) {
                                    Task { await auth.signOut() }
                                }
                                .disabled(auth.isBusy)
                                if let error = auth.errorMessage { Text(error).foregroundStyle(.red) }
                            }
                        }
                        .navigationTitle("Album Rater")
                    }
                } else {
                    AuthView(auth: auth)
                }
            }
            .task { await auth.observeSession() }
        }
    }
}
