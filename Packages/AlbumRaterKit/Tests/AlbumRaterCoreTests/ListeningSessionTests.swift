import Foundation
import Testing
@testable import AlbumRaterCore

@Suite("Media del álbum")
struct AlbumAverageTests {
    private func session(scores: [Double?]) -> ListeningSession {
        let tracks = scores.enumerated().map { index, score in
            SessionTrack(id: UUID(), position: index + 1, title: "Canción \(index + 1)",
                         rating: score.map { try! TrackRating(score: Score($0), comment: "") })
        }
        return ListeningSession(id: UUID(), albumTitle: "A", artistName: "B", createdAt: .now, tracks: tracks)
    }

    @Test func noRatingsNoAverage() {
        let album = session(scores: [nil, nil, nil])
        #expect(album.averageScore == nil)
        #expect(album.formattedAverage == nil)
        #expect(album.ratedCount == 0)
    }

    @Test("Solo cuentan las canciones puntuadas", arguments: [
        ([9, nil, nil, nil, nil], 9.0),
        ([9, 8, nil, nil, nil], 8.5),
        ([9, nil, 8, nil, 7], 8.0),
        ([10, 10, 1], 7.0),
        ([8.3, 8.4], 8.35),
    ] as [([Double?], Double)])
    func averageOfRatedTracks(scores: [Double?], expected: Double) throws {
        let average = try #require(session(scores: scores).averageScore)
        #expect(abs(average - expected) < 1e-9)
    }

    @Test func countsRatedTracks() {
        #expect(session(scores: [9, nil, 8, nil, nil]).ratedCount == 2)
    }

    @Test("Muestra la media con dos decimales como máximo")
    func formatsAverage() {
        let format = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0...2))
        #expect(session(scores: [9]).formattedAverage == 9.0.formatted(format))
        #expect(session(scores: [9, 8, 8]).formattedAverage == (25.0 / 3).formatted(format))
    }
}

@Suite("Respuesta de Supabase")
struct SessionDecodingTests {
    private let json = """
    {"id":"8F7C2B4E-1111-4000-8000-000000000001","album_title":"A","artist_name":"B",
     "created_at":"2026-09-28T10:00:00Z","session_tracks":[
      {"id":"8F7C2B4E-1111-4000-8000-000000000003","position":2,"title":"Dos","track_ratings":[]},
      {"id":"8F7C2B4E-1111-4000-8000-000000000002","position":1,"title":"Uno",
       "track_ratings":[{"score":8.3,"comment":"Genial"}]}]}
    """

    private func decode() throws -> ListeningSession {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ListeningSession.self, from: Data(json.utf8))
    }

    @Test func decodesSessionTracksAndRatings() throws {
        let session = try decode()
        #expect(session.albumTitle == "A")
        #expect(session.artistName == "B")
        #expect(session.createdAt == Date(timeIntervalSince1970: 1_790_589_600))
        #expect(session.tracks.map(\.title) == ["Uno", "Dos"], "ordenadas por posición aunque lleguen desordenadas")
        #expect(session.tracks[0].rating == (try TrackRating(score: Score(8.3), comment: "Genial")))
        #expect(session.tracks[1].rating == nil)
        #expect(session.averageScore == 8.3)
    }

    @Test func decodesProfile() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let profile = try decoder.decode(Profile.self, from: Data("""
        {"id":"8F7C2B4E-1111-4000-8000-000000000009","username":"jaime","display_name":"Jaime",
         "created_at":"2026-09-28T10:00:00Z"}
        """.utf8))
        #expect(profile.username == "jaime")
        #expect(profile.displayName == "Jaime")
    }
}
