import SwiftUI
import Supabase

struct ProfileView: View {
    let email: String
    let auth: AuthStore
    @State private var store: ProfileStore
    @State private var username = ""
    @State private var displayName = ""

    init(user: User, auth: AuthStore, client: SupabaseClient) {
        self.email = user.email ?? ""
        self.auth = auth
        _store = State(initialValue: ProfileStore(
            userID: user.id,
            repository: SupabaseProfileRepository(client: client)
        ))
    }

    var body: some View {
        NavigationStack {
            Form {
                switch store.state {
                case .loading:
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
                case .ready(let profile):
                    Section("Tu perfil") {
                        LabeledContent("Nombre", value: profile.displayName)
                        LabeledContent("Usuario", value: "@\(profile.username)")
                        if !email.isEmpty { LabeledContent("Email", value: email) }
                    }
                    Section {
                        ContentUnavailableView(
                            "Tu historial empieza aquí",
                            systemImage: "opticaldisc",
                            description: Text("Las sesiones, las notas y los amigos serán el siguiente paso.")
                        )
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
        .task { await store.load() }
    }

    @ViewBuilder private var errorMessage: some View {
        if let message = store.errorMessage {
            Text(message).foregroundStyle(.red).accessibilityLabel("Error: \(message)")
        }
    }
}
