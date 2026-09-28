import AlbumRaterCore
import SwiftUI

struct NewReviewView: View {
    let store: ReviewsStore
    let onCreated: (ListeningSession) -> Void
    @Environment(\.dismiss) private var dismiss
    // Un id por formulario: si se pierde la respuesta y reintentas, no se duplica el álbum.
    @State private var draftID = UUID()
    @State private var albumTitle = ""
    @State private var artistName = ""
    @State private var trackList = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var trackCount: Int { NewSessionInput.trackCount(in: trackList) }
    private var canSave: Bool {
        !albumTitle.trimmingCharacters(in: .whitespaces).isEmpty &&
        !artistName.trimmingCharacters(in: .whitespaces).isEmpty &&
        trackCount > 0 && !isSaving
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Álbum") {
                    TextField("Título", text: $albumTitle)
                    TextField("Artista", text: $artistName)
                }
                Section {
                    TextEditor(text: $trackList)
                        .frame(minHeight: 180)
                        .autocorrectionDisabled()
                        .accessibilityLabel("Canciones, una por línea")
                } header: {
                    Text("Canciones")
                } footer: {
                    Text(trackCount == 0
                         ? "Escribe o pega una canción por línea, en orden."
                         : "\(trackCount) \(trackCount == 1 ? "canción" : "canciones"). Las líneas vacías se ignoran.")
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).accessibilityLabel("Error: \(errorMessage)")
                }
            }
            .disabled(isSaving)
            .navigationTitle("Nuevo álbum")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(isSaving)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }.disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Guardar", action: save).disabled(!canSave)
                    }
                }
            }
        }
    }

    private func save() {
        isSaving = true
        errorMessage = nil
        Task {
            defer { isSaving = false }
            do {
                let session = try await store.create(
                    id: draftID, albumTitle: albumTitle, artistName: artistName, trackList: trackList
                )
                dismiss()
                onCreated(session)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
