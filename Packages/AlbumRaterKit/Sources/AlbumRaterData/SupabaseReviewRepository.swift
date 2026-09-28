import AlbumRaterCore
import Foundation
import Supabase

@MainActor
public struct SupabaseReviewRepository: ReviewRepository {
    let client: SupabaseClient
    let userID: UUID

    public init(client: SupabaseClient, userID: UUID) {
        self.client = client
        self.userID = userID
    }

    // Sesión, canciones y la nota propia de cada canción en una sola petición.
    private static let columns =
        "id, album_title, artist_name, created_at, session_tracks(id, position, title, track_ratings(score, comment))"

    public func loadAll() async throws -> [ListeningSession] {
        do {
            return try await client.from("listening_sessions")
                .select(Self.columns)
                .order("created_at", ascending: false)
                .execute().value
        } catch {
            throw map(error)
        }
    }

    public func create(_ input: NewSessionInput) async throws -> ListeningSession {
        do {
            try await client.rpc("create_listening_session", params: input).execute()
        } catch let error as PostgrestError where error.code == "23505" {
            // La respuesta anterior pudo perderse después de guardarse: recuperamos la sesión.
        } catch {
            throw map(error)
        }
        guard let session = try await load(id: input.id) else { throw ReviewError.unavailable }
        return session
    }

    public func setRating(_ rating: TrackRating, trackID: UUID) async throws {
        do {
            try await client.rpc("set_track_rating", params: RatingParams(trackID: trackID, rating: rating)).execute()
        } catch {
            throw map(error)
        }
    }

    public func clearRating(trackID: UUID) async throws {
        do {
            try await client.from("track_ratings")
                .delete(returning: .minimal)
                .eq("track_id", value: trackID.uuidString)
                .eq("user_id", value: userID.uuidString)
                .execute()
        } catch {
            throw map(error)
        }
    }

    public func delete(sessionID: UUID) async throws {
        do {
            try await client.from("listening_sessions")
                .delete(returning: .minimal)
                .eq("id", value: sessionID.uuidString)
                .execute()
        } catch {
            throw map(error)
        }
    }

    private func load(id: UUID) async throws -> ListeningSession? {
        do {
            let sessions: [ListeningSession] = try await client.from("listening_sessions")
                .select(Self.columns)
                .eq("id", value: id.uuidString)
                .limit(1)
                .execute().value
            return sessions.first
        } catch {
            throw map(error)
        }
    }

    private func map(_ error: Error) -> Error {
        guard let error = error as? PostgrestError else { return error }
        switch error.code {
        case "42P01", "42883", "PGRST202", "PGRST205": return ReviewError.backendNotReady
        case "42501", "PGRST301", "PGRST302", "PGRST303": return ReviewError.accessDenied
        default: return ReviewError.unavailable
        }
    }

    // Nombres de los parámetros de set_track_rating. Se envía null explícito para borrar el comentario.
    private struct RatingParams: Encodable {
        let trackID: UUID
        let rating: TrackRating

        enum CodingKeys: String, CodingKey {
            case trackID = "p_track_id", score = "p_score", comment = "p_comment"
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(trackID, forKey: .trackID)
            try container.encode(rating.score.decimalValue, forKey: .score)
            try container.encode(rating.comment, forKey: .comment)
        }
    }
}
