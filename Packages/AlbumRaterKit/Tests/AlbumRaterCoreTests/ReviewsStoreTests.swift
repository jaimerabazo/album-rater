import Foundation
import Testing
@testable import AlbumRaterCore

@Suite("Historial y notas") @MainActor
struct ReviewsStoreTests {
    let repo = FakeReviews()

    /// Store con un álbum de cinco canciones ya creado.
    private func storeWithAlbum() async throws -> (ReviewsStore, ListeningSession) {
        let store = ReviewsStore(repository: repo)
        await store.load()
        let album = try await store.create(id: UUID(), albumTitle: "Álbum", artistName: "Artista",
                                           trackList: "1\n2\n3\n4\n5")
        return (store, album)
    }

    @Test func emptyHistory() async {
        let store = ReviewsStore(repository: repo)
        #expect(store.state == .loading)
        await store.load()
        #expect(store.state == .ready)
        #expect(store.sessions.isEmpty)
    }

    @Test("La media se recalcula a medida que se puntúan canciones")
    func averageUpdatesWithEachRating() async throws {
        let (store, album) = try await storeWithAlbum()
        let tracks = album.tracks.map(\.id)
        func current() -> ListeningSession { store.session(id: album.id)! }
        #expect(current().averageScore == nil)

        try await store.saveRating(trackID: tracks[0], sessionID: album.id, scoreText: "9", comment: "")
        #expect(current().averageScore == 9)
        try await store.saveRating(trackID: tracks[1], sessionID: album.id, scoreText: "8", comment: "Bien")
        #expect(current().averageScore == 8.5)
        #expect(current().ratedCount == 2)

        try await store.saveRating(trackID: tracks[1], sessionID: album.id, scoreText: "7,5", comment: "")
        #expect(current().averageScore == 8.25, "cambiar una nota recalcula la media")
        #expect(current().tracks[1].rating?.comment == nil, "el comentario también se sustituye")

        try await store.clearRating(trackID: tracks[1], sessionID: album.id)
        #expect(current().averageScore == 9, "quitar una nota recalcula la media")
        #expect(current().ratedCount == 1)
    }

    @Test("Una nota inválida no llega al servidor", arguments: ["", "0", "10,5", "8,25", "diez"])
    func invalidScoreIsNotSent(text: String) async throws {
        let (store, album) = try await storeWithAlbum()
        await #expect(throws: ReviewError.invalidScore) {
            try await store.saveRating(trackID: album.tracks[0].id, sessionID: album.id, scoreText: text, comment: "")
        }
        #expect(repo.ratingCalls == 0)
    }

    @Test func tooLongCommentIsNotSent() async throws {
        let (store, album) = try await storeWithAlbum()
        await #expect(throws: ReviewError.invalidComment) {
            try await store.saveRating(trackID: album.tracks[0].id, sessionID: album.id,
                                       scoreText: "8", comment: String(repeating: "a", count: 1001))
        }
        #expect(repo.ratingCalls == 0)
    }

    @Test("Si el servidor falla, se conserva la nota anterior: nunca un guardado falso")
    func serverFailureKeepsPreviousRating() async throws {
        let (store, album) = try await storeWithAlbum()
        let track = album.tracks[0].id
        try await store.saveRating(trackID: track, sessionID: album.id, scoreText: "9", comment: "")

        repo.error = ReviewError.accessDenied
        await #expect(throws: ReviewError.accessDenied) {
            try await store.saveRating(trackID: track, sessionID: album.id, scoreText: "2", comment: "")
        }
        repo.error = URLError(.notConnectedToInternet)
        await #expect(throws: ReviewError.unavailable) {
            try await store.clearRating(trackID: track, sessionID: album.id)
        }
        #expect(store.session(id: album.id)?.tracks[0].rating?.score == Score(9))
    }

    @Test("Una canción o sesión desconocida no cambia nada")
    func unknownIDsAreIgnored() async throws {
        let (store, album) = try await storeWithAlbum()
        try await store.saveRating(trackID: UUID(), sessionID: album.id, scoreText: "9", comment: "")
        try await store.saveRating(trackID: album.tracks[0].id, sessionID: UUID(), scoreText: "9", comment: "")
        #expect(store.session(id: album.id)?.ratedCount == 0)
    }

    @Test func createdAlbumGoesFirst() async throws {
        let (store, first) = try await storeWithAlbum()
        let second = try await store.create(id: UUID(), albumTitle: "Otro", artistName: "B", trackList: "x")
        #expect(store.sessions.map(\.id) == [second.id, first.id])
    }

    @Test("Reintentar la creación con el mismo id no duplica el álbum")
    func createRetryIsIdempotent() async throws {
        let (store, album) = try await storeWithAlbum()
        try await store.saveRating(trackID: album.tracks[0].id, sessionID: album.id, scoreText: "9", comment: "")
        _ = try await store.create(id: album.id, albumTitle: "Álbum", artistName: "Artista", trackList: "1\n2\n3\n4\n5")
        #expect(store.sessions.count == 1)
        #expect(repo.sessions.count == 1)
        #expect(store.session(id: album.id)?.ratedCount == 1, "conserva las notas del servidor")
    }

    @Test("Crear un álbum inválido no llega al servidor")
    func invalidAlbumIsNotSent() async {
        let store = ReviewsStore(repository: repo)
        await #expect(throws: ReviewError.invalidTrackCount) {
            try await store.create(id: UUID(), albumTitle: "A", artistName: "B", trackList: "")
        }
        #expect(repo.creates == 0)
    }

    @Test func createFailureIsReported() async {
        let store = ReviewsStore(repository: repo)
        repo.error = URLError(.timedOut)
        await #expect(throws: ReviewError.unavailable) {
            try await store.create(id: UUID(), albumTitle: "A", artistName: "B", trackList: "x")
        }
        #expect(store.sessions.isEmpty)
    }

    @Test("Un error de carga inicial no parece un historial vacío")
    func initialLoadFailure() async {
        repo.error = ReviewError.backendNotReady
        let store = ReviewsStore(repository: repo)
        await store.load()
        #expect(store.state == .failed)
        #expect(store.errorMessage == ReviewError.backendNotReady.errorDescription)
        repo.error = nil
        await store.load()
        #expect(store.state == .ready)
        #expect(store.errorMessage == nil)
    }

    @Test("Un fallo al recargar conserva lo que ya se ve")
    func reloadFailureKeepsData() async throws {
        let (store, _) = try await storeWithAlbum()
        repo.error = URLError(.timedOut)
        await store.load()
        #expect(store.state == .ready)
        #expect(store.sessions.count == 1)
        #expect(store.errorMessage == ReviewError.unavailable.errorDescription)
        store.dismissError()
        #expect(store.errorMessage == nil)
    }

    @Test func deleteAlbum() async throws {
        let (store, album) = try await storeWithAlbum()
        repo.error = URLError(.timedOut)
        await store.delete(sessionID: album.id)
        #expect(store.sessions.count == 1, "un fallo conserva el álbum")
        #expect(store.errorMessage != nil)
        repo.error = nil
        await store.delete(sessionID: album.id)
        #expect(store.sessions.isEmpty)
        #expect(store.session(id: album.id) == nil)
        #expect(store.errorMessage == nil)
    }

    @Test("Cancelar la carga no muestra un error falso")
    func cancelledLoad() async {
        repo.delay = .seconds(10)
        let store = ReviewsStore(repository: repo)
        let task = Task { await store.load() }
        await Task.yield()
        task.cancel()
        await task.value
        #expect(store.state == .loading)
        #expect(store.errorMessage == nil)
    }
}
