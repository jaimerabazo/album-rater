import Foundation
import Testing
@testable import AlbumRaterCore

// Los mismos límites se comprueban en PostgreSQL (supabase/tests). Aquí se prueba que la app
// no envía nada que el servidor vaya a rechazar, y que los mensajes de error son los correctos.

@Suite("Validación del perfil")
struct ProfileInputTests {
    @Test func normalizesUsernameAndName() throws {
        let input = try ProfileInput(id: UUID(), username: "  Jaime_R\n", displayName: " Jaime ")
        #expect(input.username == "jaime_r")
        #expect(input.displayName == "Jaime")
    }

    @Test("Rechaza usernames inválidos", arguments: [
        "ab", String(repeating: "a", count: 31), "name space", "josé", "name\nfoo", "👋", "a-b",
    ])
    func rejectsUsername(username: String) {
        #expect(throws: ProfileError.invalidUsername) {
            try ProfileInput(id: UUID(), username: username, displayName: "Valid")
        }
    }

    @Test("Acepta nombres con emoji compuestos", arguments: ["Jaime 👨‍💻", "Ana 🇪🇸", "José ❤️", "李"])
    func acceptsDisplayName(name: String) throws {
        #expect(try ProfileInput(id: UUID(), username: "valid", displayName: name).displayName == name)
    }

    @Test("Rechaza nombres vacíos, largos o con saltos de línea", arguments: [
        "  ", "", String(repeating: "a", count: 51), "a\nb", "a\tb", "a\u{2028}b", "a\u{2029}b",
    ])
    func rejectsDisplayName(name: String) {
        #expect(throws: ProfileError.invalidDisplayName) {
            try ProfileInput(id: UUID(), username: "valid", displayName: name)
        }
    }

    @Test func encodesDatabaseColumns() throws {
        let id = UUID()
        let json = try JSONEncoder().encode(ProfileInput(id: id, username: "jaime", displayName: "Jaime"))
        let object = try #require(JSONSerialization.jsonObject(with: json) as? [String: String])
        #expect(object == ["id": id.uuidString, "username": "jaime", "display_name": "Jaime"])
    }
}

@Suite("Validación de un álbum nuevo")
struct NewSessionInputTests {
    @Test func oneTrackPerLine() throws {
        let input = try NewSessionInput(id: UUID(), albumTitle: " OK Computer ", artistName: "Radiohead",
                                        trackList: "Airbag\n\n  Paranoid Android \r\nSubterranean Homesick Alien\n")
        #expect(input.albumTitle == "OK Computer")
        #expect(input.artistName == "Radiohead")
        #expect(input.trackTitles == ["Airbag", "Paranoid Android", "Subterranean Homesick Alien"])
    }

    @Test func countsTracksIgnoringBlankLines() {
        #expect(NewSessionInput.trackCount(in: "a\n \nb\n") == 2)
        #expect(NewSessionInput.trackCount(in: "") == 0)
    }

    @Test("Acepta 100 canciones y títulos de 200 caracteres")
    func acceptsLimits() throws {
        let input = try NewSessionInput(
            id: UUID(), albumTitle: String(repeating: "a", count: 200), artistName: "B",
            trackList: Array(repeating: String(repeating: "t", count: 200), count: 100).joined(separator: "\n")
        )
        #expect(input.trackTitles.count == 100)
    }

    @Test("Rechaza cada campo inválido con su mensaje", arguments: [
        ("", "A", "x", ReviewError.invalidAlbumTitle),
        (String(repeating: "a", count: 201), "A", "x", .invalidAlbumTitle),
        ("A\nB", "A", "x", .invalidAlbumTitle),
        ("A", "  ", "x", .invalidArtistName),
        ("A", "B", "\n \n", .invalidTrackCount),
        ("A", "B", Array(repeating: "x", count: 101).joined(separator: "\n"), .invalidTrackCount),
        ("A", "B", "ok\n" + String(repeating: "a", count: 201), .invalidTrackTitle(position: 2)),
        ("A", "B", "ok\nuno\tdos", .invalidTrackTitle(position: 2)),
    ])
    func rejects(album: String, artist: String, tracks: String, expected: ReviewError) {
        #expect(throws: expected) {
            try NewSessionInput(id: UUID(), albumTitle: album, artistName: artist, trackList: tracks)
        }
    }

    @Test func encodesFunctionParameters() throws {
        let id = UUID()
        let input = try NewSessionInput(id: id, albumTitle: "A", artistName: "B", trackList: "Uno\nDos")
        let object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(input)) as? [String: Any])
        #expect(object["p_id"] as? String == id.uuidString)
        #expect(object["p_album_title"] as? String == "A")
        #expect(object["p_artist_name"] as? String == "B")
        #expect(object["p_track_titles"] as? [String] == ["Uno", "Dos"])
    }
}

@Suite("Validación de una nota")
struct TrackRatingTests {
    @Test func trimsComment() throws {
        #expect(try TrackRating(score: Score(8), comment: "  Muy buena\n").comment == "Muy buena")
    }

    @Test("Un comentario vacío se guarda como nil", arguments: ["", "  \n ", "\t"])
    func emptyCommentIsNil(comment: String) throws {
        #expect(try TrackRating(score: Score(8), comment: comment).comment == nil)
    }

    @Test func commentsCanHaveLineBreaks() throws {
        #expect(try TrackRating(score: Score(8), comment: "Línea 1\nLínea 2").comment == "Línea 1\nLínea 2")
    }

    @Test func commentLimit() throws {
        #expect(try TrackRating(score: Score(8), comment: String(repeating: "a", count: 1000)).comment?.count == 1000)
        #expect(throws: ReviewError.invalidComment) {
            try TrackRating(score: Score(8), comment: String(repeating: "a", count: 1001))
        }
    }
}

@Suite("Mensajes de error")
struct ErrorMessageTests {
    @Test("Cada error del perfil tiene un mensaje para la persona", arguments: [
        ProfileError.invalidUsername, .invalidDisplayName, .usernameTaken, .backendNotReady, .accessDenied, .unavailable,
    ])
    func profileMessages(error: ProfileError) {
        #expect(error.errorDescription?.isEmpty == false)
    }

    @Test("Cada error de reviews tiene un mensaje para la persona", arguments: [
        ReviewError.invalidAlbumTitle, .invalidArtistName, .invalidTrackCount, .invalidTrackTitle(position: 3),
        .invalidScore, .invalidComment, .backendNotReady, .accessDenied, .unavailable,
    ])
    func reviewMessages(error: ReviewError) {
        #expect(error.errorDescription?.isEmpty == false)
    }

    @Test func trackTitleMessageNamesThePosition() {
        #expect(ReviewError.invalidTrackTitle(position: 7).errorDescription?.contains("7") == true)
    }
}
