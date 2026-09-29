import AlbumRaterCore
import AlbumRaterData
import SwiftUI
import Supabase

/// Carga el perfil o lo pide si falta. Con el perfil listo, muestra el historial de álbumes.
struct ProfileView: View {
    let email: String
    let auth: AuthStore
    private let userID: UUID
    private let client: SupabaseClient
    @State private var store: ProfileStore
    @State private var username = ""
    @State private var displayName = ""

    init(user: User, auth: AuthStore, client: SupabaseClient) {
        self.email = user.email ?? ""
        self.auth = auth
        self.userID = user.id
        self.client = client
        _store = State(initialValue: ProfileStore(
            userID: user.id,
            repository: SupabaseProfileRepository(client: client)
        ))
    }

    var body: some View {
        Group {
            if case .ready(let profile) = store.state {
                ReviewListView(
                    profile: profile, profileStore: store, email: email, auth: auth,
                    repository: SupabaseReviewRepository(client: client, userID: userID)
                )
            } else {
                onboarding
            }
        }
        .task { await store.load() }
    }

    private var onboarding: some View {
        NavigationStack {
            Form {
                switch store.state {
                case .loading, .ready:
                    ProgressView("Cargando tu perfil…")
                case .failed:
                    Section("No se ha podido cargar el perfil") {
                        errorMessage
                        Button("Reintentar") { Task { await store.load() } }
                    }
                case .needsProfile:
                    Section {
                        Text("Tu cuenta está creada. Elige cómo quieres aparecer en Album Rater.")
                    }
                    Section("Completa tu perfil") {
                        TextField("Nombre visible", text: $displayName)
                            .textContentType(.nickname)
                        TextField("Nombre de usuario", text: $username)
                            .textContentType(.username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.asciiCapable)
                        Text("El nombre de usuario es único. Usa entre 3 y 30 letras, números o guiones bajos. Se guardará en minúsculas.")
                            .font(.caption).foregroundStyle(.secondary)
                        errorMessage
                        Button {
                            Task { await store.save(username: username, displayName: displayName) }
                        } label: {
                            HStack {
                                Text("Guardar perfil")
                                if store.isSaving { ProgressView() }
                            }
                        }
                        .disabled(username.isEmpty || displayName.isEmpty)
                    }
                }
                Section {
                    Button("Cerrar sesión", role: .destructive) { Task { await auth.signOut() } }
                    if let error = auth.errorMessage { Text(error).foregroundStyle(.red) }
                }
            }
            .disabled(store.isSaving || auth.isBusy)
            .navigationTitle("Album Rater")
        }
    }

    @ViewBuilder private var errorMessage: some View {
        if let message = store.errorMessage {
            Text(message).foregroundStyle(.red).accessibilityLabel("Error: \(message)")
        }
    }
}
