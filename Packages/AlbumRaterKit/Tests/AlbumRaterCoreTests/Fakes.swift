import Foundation
@testable import AlbumRaterCore

/// Repositorio en memoria que imita al de Supabase: sin red y controlable desde cada test.
@MainActor
final class FakeProfiles: ProfileRepository {
    var saved: Profile?
    var error: Error?
    var delay: Duration?
    private(set) var creates = 0

    func load(userID: UUID) async throws -> Profile? {
        if let delay { try await Task.sleep(for: delay) }
        if let error { throw error }
        return saved
    }

    func create(_ input: ProfileInput) async throws -> Profile {
        creates += 1
        if let delay { try await Task.sleep(for: delay) }
        if let error { throw error }
        let profile = Profile(id: input.id, username: input.username,
                              displayName: input.displayName, createdAt: .now)
        saved = profile
        return profile
    }
}

@MainActor
final class FakeReviews: ReviewRepository {
    var sessions: [ListeningSession] = []
    var error: Error?
    var delay: Duration?
    private(set) var creates = 0
    private(set) var ratingCalls = 0

    func loadAll() async throws -> [ListeningSession] {
        if let delay { try await Task.sleep(for: delay) }
        if let error { throw error }
        return sessions
    }

    func create(_ input: NewSessionInput) async throws -> ListeningSession {
        creates += 1
        if let error { throw error }
        // Como el repositorio real: con un id ya guardado devuelve la sesión existente.
        if let existing = sessions.first(where: { $0.id == input.id }) { return existing }
        let tracks = input.trackTitles.enumerated().map { SessionTrack(id: UUID(), position: $0 + 1, title: $1) }
        let session = ListeningSession(id: input.id, albumTitle: input.albumTitle,
                                       artistName: input.artistName, createdAt: .now, tracks: tracks)
        sessions.insert(session, at: 0)
        return session
    }

    func setRating(_ rating: TrackRating, trackID: UUID) async throws {
        ratingCalls += 1
        if let error { throw error }
        update(trackID) { $0.rating = rating }
    }

    func clearRating(trackID: UUID) async throws {
        if let error { throw error }
        update(trackID) { $0.rating = nil }
    }

    func delete(sessionID: UUID) async throws {
        if let error { throw error }
        sessions.removeAll { $0.id == sessionID }
    }

    private func update(_ trackID: UUID, _ change: (inout SessionTrack) -> Void) {
        for s in sessions.indices {
            if let t = sessions[s].tracks.firstIndex(where: { $0.id == trackID }) { change(&sessions[s].tracks[t]) }
        }
    }
}

extension Score {
    /// Atajo para tests: `.init(8.5)`.
    init(_ value: Double) {
        self.init(tenths: Int((value * 10).rounded()))!
    }
}
