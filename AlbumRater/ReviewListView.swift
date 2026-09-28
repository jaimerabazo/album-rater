import AlbumRaterCore
import SwiftUI

struct ReviewListView: View {
    let profile: Profile
    let email: String
    let auth: AuthStore
    @State private var store: ReviewsStore
    @State private var path: [UUID] = []
    @State private var isAdding = false
    @State private var sessionToDelete: ListeningSession?

    init(profile: Profile, email: String, auth: AuthStore, repository: any ReviewRepository) {
        self.profile = profile
        self.email = email
        self.auth = auth
        _store = State(initialValue: ReviewsStore(repository: repository))
    }

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationTitle("Album Rater")
                .navigationDestination(for: UUID.self) { id in
                    ReviewDetailView(sessionID: id, store: store)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { profileMenu }
                    ToolbarItem(placement: .primaryAction) {
                        Button("Añadir álbum", systemImage: "plus") { isAdding = true }
                            .disabled(store.state != .ready)
                    }
                }
                .sheet(isPresented: $isAdding) {
                    NewReviewView(store: store) { session in path.append(session.id) }
                }
                .confirmationDialog(
                    "¿Borrar «\(sessionToDelete?.albumTitle ?? "")»?",
                    isPresented: Binding(get: { sessionToDelete != nil }, set: { if !$0 { sessionToDelete = nil } }),
                    titleVisibility: .visible,
                    presenting: sessionToDelete
                ) { session in
                    Button("Borrar álbum y notas", role: .destructive) {
                        Task { await store.delete(sessionID: session.id) }
                    }
                } message: { _ in
                    Text("Se borrarán sus canciones y tus notas. No se puede deshacer.")
                }
                .alert(
                    "Algo ha fallado",
                    isPresented: Binding(
                        get: { store.state == .ready && store.errorMessage != nil },
                        set: { if !$0 { store.dismissError() } }
                    )
                ) {} message: {
                    Text(store.errorMessage ?? "")
                }
                .alert(
                    "No se ha podido cerrar sesión",
                    isPresented: Binding(get: { auth.errorMessage != nil }, set: { if !$0 { auth.errorMessage = nil } })
                ) {} message: {
                    Text(auth.errorMessage ?? "")
                }
        }
        .task { await store.load() }
    }

    @ViewBuilder private var content: some View {
        switch store.state {
        case .loading:
            ProgressView("Cargando tus álbumes…")
        case .failed:
            ContentUnavailableView {
                Label("No se han podido cargar tus álbumes", systemImage: "exclamationmark.triangle")
            } description: {
                Text(store.errorMessage ?? "")
            } actions: {
                Button("Reintentar") { Task { await store.load() } }
            }
        case .ready where store.sessions.isEmpty:
            ContentUnavailableView {
                Label("Tu historial empieza aquí", systemImage: "opticaldisc")
            } description: {
                Text("Añade un álbum y puntúa sus canciones. La media se calcula sola.")
            } actions: {
                Button("Añadir álbum") { isAdding = true }
                    .buttonStyle(.borderedProminent)
            }
        case .ready:
            List {
                ForEach(store.sessions) { session in
                    NavigationLink(value: session.id) {
                        SessionRow(session: session)
                    }
                    .accessibilityIdentifier("session-row")
                    .swipeActions {
                        Button("Borrar", systemImage: "trash", role: .destructive) {
                            sessionToDelete = session
                        }
                    }
                }
            }
            .refreshable { await store.load() }
        }
    }

    private var profileMenu: some View {
        Menu {
            Section {
                Text(profile.displayName)
                Text("@\(profile.username)")
                if !email.isEmpty { Text(email) }
            }
            Button("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                Task { await auth.signOut() }
            }
        } label: {
            Label("Perfil", systemImage: "person.crop.circle")
        }
        .disabled(auth.isBusy)
    }
}

private struct SessionRow: View {
    let session: ListeningSession

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.albumTitle).font(.headline)
                Text(session.artistName).foregroundStyle(.secondary)
                Text(session.createdAt, format: .dateTime.day().month().year())
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(session.formattedAverage ?? "–")
                    .font(.title2.bold().monospacedDigit())
                Text("\(session.ratedCount)/\(session.tracks.count)")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(session.formattedAverage.map { "Media \($0)" } ?? "Sin notas")
    }
}
