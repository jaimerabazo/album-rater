import AlbumRaterCore
import Foundation
import Testing
@testable import AlbumRaterData

@Suite("Repositorio de reviews contra Supabase local", .enabled(if: LocalSupabase.isConfigured)) @MainActor
struct SupabaseReviewRepositoryTests {
    private func newAlbum(_ repository: SupabaseReviewRepository, tracks: String = "Uno\nDos\nTres") async throws
        -> ListeningSession {
        try await repository.create(NewSessionInput(id: UUID(), albumTitle: "Álbum", artistName: "Artista", trackList: tracks))
    }

    private func repository() async throws -> SupabaseReviewRepository {
        let (client, userID) = try await LocalSupabase.newAccount()
        return SupabaseReviewRepository(client: client, userID: userID)
    }

    @Test func createReturnsTracksInOrder() async throws {
        let repository = try await repository()
        let album = try await newAlbum(repository)
        #expect(album.albumTitle == "Álbum")
        #expect(album.tracks.map(\.title) == ["Uno", "Dos", "Tres"])
        #expect(album.tracks.map(\.position) == [1, 2, 3])
        #expect(album.tracks.allSatisfy { $0.rating == nil })
        #expect(try await repository.loadAll() == [album])
    }

    @Test("Reintentar con el mismo id devuelve el álbum guardado sin duplicarlo")
    func createRetryIsIdempotent() async throws {
        let repository = try await repository()
        let input = try NewSessionInput(id: UUID(), albumTitle: "A", artistName: "B", trackList: "x\ny")
        let first = try await repository.create(input)
        #expect(try await repository.create(input) == first)
        #expect(try await repository.loadAll().count == 1)
    }

    @Test func newestAlbumFirst() async throws {
        let repository = try await repository()
        let older = try await newAlbum(repository)
        let newer = try await newAlbum(repository)
        #expect(try await repository.loadAll().map(\.id) == [newer.id, older.id])
    }

    @Test("Guardar, sustituir y quitar notas; la media sale de lo guardado")
    func ratingsRoundTrip() async throws {
        let repository = try await repository()
        let album = try await newAlbum(repository)
        let first = album.tracks[0].id, second = album.tracks[1].id

        try await repository.setRating(TrackRating(score: Score(parsing: "9")!, comment: ""), trackID: first)
        try await repository.setRating(TrackRating(score: Score(parsing: "8")!, comment: "Muy buena"), trackID: second)
        var saved = try #require(try await repository.loadAll().first)
        #expect(saved.averageScore == 8.5)
        #expect(saved.tracks[1].rating?.comment == "Muy buena")

        try await repository.setRating(TrackRating(score: Score(parsing: "7,5")!, comment: ""), trackID: second)
        saved = try #require(try await repository.loadAll().first)
        #expect(saved.tracks[1].rating?.score == Score(parsing: "7.5"))
        #expect(saved.tracks[1].rating?.comment == nil, "un comentario vacío borra el anterior")

        try await repository.clearRating(trackID: second)
        try await repository.clearRating(trackID: second)
        saved = try #require(try await repository.loadAll().first)
        #expect(saved.ratedCount == 1, "quitar dos veces no falla")
        #expect(saved.averageScore == 9)
    }

    @Test func deleteAlbum() async throws {
        let repository = try await repository()
        let album = try await newAlbum(repository)
        try await repository.setRating(TrackRating(score: Score(parsing: "9")!, comment: ""), trackID: album.tracks[0].id)
        try await repository.delete(sessionID: album.id)
        #expect(try await repository.loadAll().isEmpty)
    }

    @Test("Otra cuenta no ve, puntúa ni borra mis álbumes")
    func isolationBetweenAccounts() async throws {
        let mine = try await repository()
        let album = try await newAlbum(mine)
        let other = try await repository()

        #expect(try await other.loadAll().isEmpty)
        await #expect(throws: ReviewError.accessDenied) {
            try await other.setRating(TrackRating(score: Score(parsing: "1")!, comment: ""), trackID: album.tracks[0].id)
        }
        try await other.delete(sessionID: album.id)
        try await other.clearRating(trackID: album.tracks[0].id)
        #expect(try await mine.loadAll() == [album], "borrar algo ajeno no tiene efecto")
    }

    @Test("Sin sesión no hay acceso")
    func anonymousAccessIsDenied() async throws {
        let repository = SupabaseReviewRepository(client: LocalSupabase.anonymousClient(), userID: UUID())
        await #expect(throws: ReviewError.accessDenied) { _ = try await repository.loadAll() }
        await #expect(throws: ReviewError.accessDenied) {
            _ = try await repository.create(NewSessionInput(id: UUID(), albumTitle: "A", artistName: "B", trackList: "x"))
        }
    }
}
