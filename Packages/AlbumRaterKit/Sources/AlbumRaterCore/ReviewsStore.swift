import Foundation
import Observation

@MainActor
public protocol ReviewRepository {
    func loadAll() async throws -> [ListeningSession]
    func create(_ input: NewSessionInput) async throws -> ListeningSession
    func setRating(_ rating: TrackRating, trackID: UUID) async throws
    func clearRating(trackID: UUID) async throws
    func delete(sessionID: UUID) async throws
}

/// Historial de álbumes del usuario. La lista y el detalle comparten este store,
/// así que la media se actualiza en ambas pantallas en cuanto se guarda una nota.
@MainActor @Observable
public final class ReviewsStore {
    public enum State: Equatable { case loading, failed, ready }

    public private(set) var state: State = .loading
    public private(set) var sessions: [ListeningSession] = []
    public private(set) var errorMessage: String?
    private let repository: any ReviewRepository

    public init(repository: any ReviewRepository) {
        self.repository = repository
    }

    public func session(id: UUID) -> ListeningSession? {
        sessions.first { $0.id == id }
    }

    public func load() async {
        if sessions.isEmpty { state = .loading }
        errorMessage = nil
        do {
            let loaded = try await repository.loadAll()
            try Task.checkCancellation()
            sessions = loaded
            state = .ready
        } catch {
            guard !Task.isCancelled else { return }
            // Si ya había datos, los conservamos y solo avisamos.
            if sessions.isEmpty { state = .failed }
            errorMessage = Self.reviewError(error).errorDescription
        }
    }

    /// El formulario genera `id` una vez: reintentar con el mismo id nunca duplica el álbum.
    public func create(id: UUID, albumTitle: String, artistName: String, trackList: String) async throws -> ListeningSession {
        let input = try NewSessionInput(id: id, albumTitle: albumTitle, artistName: artistName, trackList: trackList)
        do {
            let session = try await repository.create(input)
            sessions.removeAll { $0.id == session.id }
            sessions.insert(session, at: 0)
            state = .ready
            return session
        } catch {
            throw Self.reviewError(error)
        }
    }

    /// Solo cambia la nota en pantalla después de que el servidor confirme el guardado.
    public func saveRating(trackID: UUID, sessionID: UUID, scoreText: String, comment: String) async throws {
        guard let score = Score(parsing: scoreText) else { throw ReviewError.invalidScore }
        let rating = try TrackRating(score: score, comment: comment)
        do {
            try await repository.setRating(rating, trackID: trackID)
        } catch {
            throw Self.reviewError(error)
        }
        updateTrack(trackID, in: sessionID) { $0.rating = rating }
    }

    public func clearRating(trackID: UUID, sessionID: UUID) async throws {
        do {
            try await repository.clearRating(trackID: trackID)
        } catch {
            throw Self.reviewError(error)
        }
        updateTrack(trackID, in: sessionID) { $0.rating = nil }
    }

    public func delete(sessionID: UUID) async {
        errorMessage = nil
        do {
            try await repository.delete(sessionID: sessionID)
            sessions.removeAll { $0.id == sessionID }
        } catch {
            errorMessage = Self.reviewError(error).errorDescription
        }
    }

    public func dismissError() {
        errorMessage = nil
    }

    private func updateTrack(_ trackID: UUID, in sessionID: UUID, _ change: (inout SessionTrack) -> Void) {
        guard let s = sessions.firstIndex(where: { $0.id == sessionID }),
              let t = sessions[s].tracks.firstIndex(where: { $0.id == trackID }) else { return }
        change(&sessions[s].tracks[t])
    }

    private static func reviewError(_ error: Error) -> ReviewError {
        error as? ReviewError ?? .unavailable
    }
}
