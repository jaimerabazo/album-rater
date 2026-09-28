import AlbumRaterCore
import SwiftUI

struct TrackRatingView: View {
    let track: SessionTrack
    let sessionID: UUID
    let store: ReviewsStore
    @Environment(\.dismiss) private var dismiss
    @State private var scoreText: String
    @State private var comment: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var scoreFocused: Bool

    init(track: SessionTrack, sessionID: UUID, store: ReviewsStore) {
        self.track = track
        self.sessionID = sessionID
        self.store = store
        _scoreText = State(initialValue: track.rating?.score.formatted ?? "")
        _comment = State(initialValue: track.rating?.comment ?? "")
    }

    private var isValidScore: Bool { Score(parsing: scoreText) != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nota", text: $scoreText)
                        .keyboardType(.decimalPad)
                        .focused($scoreFocused)
                        .font(.title.monospacedDigit())
                } header: {
                    Text("Nota")
                } footer: {
                    Text("Del 1 al 10, con un decimal como máximo. Por ejemplo, 8,5.")
                        .foregroundStyle(scoreText.isEmpty || isValidScore ? Color.secondary : Color.red)
                }
                Section("Comentario (opcional)") {
                    TextField("¿Qué te ha parecido?", text: $comment, axis: .vertical)
                        .lineLimit(3...8)
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).accessibilityLabel("Error: \(errorMessage)")
                }
                if track.rating != nil {
                    Section {
                        Button("Quitar nota", role: .destructive) { run { try await store.clearRating(trackID: track.id, sessionID: sessionID) } }
                    }
                }
            }
            .disabled(isSaving)
            .navigationTitle("\(track.position). \(track.title)")
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
                        Button("Guardar") {
                            run {
                                try await store.saveRating(trackID: track.id, sessionID: sessionID,
                                                           scoreText: scoreText, comment: comment)
                            }
                        }
                        .disabled(!isValidScore)
                    }
                }
            }
            .onAppear { if track.rating == nil { scoreFocused = true } }
        }
        .presentationDetents([.medium, .large])
    }

    /// Espera la confirmación del servidor; si falla, la hoja sigue abierta con el texto intacto.
    private func run(_ operation: @escaping () async throws -> Void) {
        isSaving = true
        errorMessage = nil
        Task {
            defer { isSaving = false }
            do {
                try await operation()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
