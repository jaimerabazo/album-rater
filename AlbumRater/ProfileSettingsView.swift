import AlbumRaterCore
import SwiftUI

/// Tu perfil: datos básicos y privacidad (M3.1).
struct ProfileSettingsView: View {
    let store: ProfileStore
    let email: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                if case .ready(let profile) = store.state {
                    Section {
                        LabeledContent("Nombre", value: profile.displayName)
                        LabeledContent("Usuario", value: "@\(profile.username)")
                        if !email.isEmpty { LabeledContent("Email", value: email) }
                    }
                    Section {
                        // El interruptor muestra lo guardado en el servidor: cambia cuando se confirma.
                        Toggle(isOn: Binding(
                            get: { profile.isPrivate },
                            set: { isPrivate in Task { await store.setPrivate(isPrivate) } }
                        )) {
                            HStack {
                                Text("Perfil privado")
                                if store.isSaving { ProgressView() }
                            }
                        }
                        .disabled(store.isSaving)
                        if let error = store.errorMessage {
                            Text(error).foregroundStyle(.red).accessibilityLabel("Error: \(error)")
                        }
                    } footer: {
                        Text(profile.isPrivate
                             ? "Solo las personas que apruebes podrán seguirte y ver tu historial."
                             : "Cualquiera puede encontrarte, seguirte y ver tu historial.")
                    }
                }
            }
            .navigationTitle("Tu perfil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hecho") { dismiss() }
                }
            }
        }
    }
}
