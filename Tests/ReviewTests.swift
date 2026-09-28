import Foundation

@MainActor
final class FakeReviews: ReviewRepository {
    var sessions: [ListeningSession] = []
    var error: Error?
    var creates = 0
    var ratingCalls = 0

    func loadAll() async throws -> [ListeningSession] {
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
    private func update(_ trackID: UUID, _ change: (inout SessionTrack) -> Void) {
        for s in sessions.indices {
            if let t = sessions[s].tracks.firstIndex(where: { $0.id == trackID }) { change(&sessions[s].tracks[t]) }
        }
    }
    func delete(sessionID: UUID) async throws {
        if let error { throw error }
        sessions.removeAll { $0.id == sessionID }
    }
}

func expect(_ condition: Bool, _ label: String) {
    precondition(condition, "FAIL: \(label)")
}

@main struct ReviewTests {
    @MainActor static func main() async throws {
        // Notas: 1–10 con un decimal como máximo, coma o punto.
        for (text, tenths) in [("9", 90), ("8,5", 85), ("8.5", 85), (" 7 ", 70), ("1", 10), ("10", 100),
                               ("10,0", 100), ("9.9", 99), ("01", 10)] {
            expect(Score(parsing: text)?.tenths == tenths, "acepta \(text)")
        }
        for text in ["", "0", "0,9", "10,1", "11", "8,55", "8,", ",5", "abc", "-5", "+5", "8 5", "٣", "1e1", "8.5.1"] {
            expect(Score(parsing: text) == nil, "rechaza «\(text)»")
        }

        // Validación del álbum y las canciones.
        let input = try NewSessionInput(id: UUID(), albumTitle: " OK Computer ", artistName: "Radiohead",
                                        trackList: "Airbag\n\n  Paranoid Android \r\nSubterranean Homesick Alien\n")
        expect(input.albumTitle == "OK Computer", "recorta el título")
        expect(input.trackTitles == ["Airbag", "Paranoid Android", "Subterranean Homesick Alien"], "una canción por línea")
        expect(NewSessionInput.trackCount(in: "a\n \nb\n") == 2, "cuenta canciones sin líneas vacías")
        for (album, artist, tracks, expected) in [
            ("", "A", "x", ReviewError.invalidAlbumTitle),
            ("A", "  ", "x", .invalidArtistName),
            ("A", "B", "\n \n", .invalidTrackCount),
            ("A", "B", Array(repeating: "x", count: 101).joined(separator: "\n"), .invalidTrackCount),
            ("A", "B", "ok\n" + String(repeating: "a", count: 201), .invalidTrackTitle(position: 2)),
            ("A", "B", "ok\nuno\tdos", .invalidTrackTitle(position: 2)),
        ] {
            do {
                _ = try NewSessionInput(id: UUID(), albumTitle: album, artistName: artist, trackList: tracks)
                expect(false, "aceptó una entrada inválida: \(expected)")
            } catch let error as ReviewError {
                expect(error == expected, "error \(expected), recibido \(error)")
            }
        }
        expect((try? TrackRating(score: Score(tenths: 80)!, comment: String(repeating: "a", count: 1001))) == nil,
               "comentario de más de 1000 caracteres")
        expect(try TrackRating(score: Score(tenths: 80)!, comment: "  \n ").comment == nil, "comentario vacío es nil")

        // La media se recalcula a medida que se puntúan canciones.
        let repo = FakeReviews()
        let store = ReviewsStore(repository: repo)
        await store.load()
        expect(store.state == .ready && store.sessions.isEmpty, "historial vacío")
        let draftID = UUID()
        let created = try await store.create(id: draftID, albumTitle: "Álbum", artistName: "Artista",
                                             trackList: "1\n2\n3\n4\n5")
        let tracks = created.tracks.map(\.id)
        func current() -> ListeningSession { store.session(id: created.id)! }
        expect(current().averageScore == nil && current().ratedCount == 0, "sin notas no hay media")

        try await store.saveRating(trackID: tracks[0], sessionID: created.id, scoreText: "9", comment: "")
        expect(current().averageScore == 9 && current().formattedAverage == 9.0.formatted(), "una nota de 9: media 9")
        try await store.saveRating(trackID: tracks[1], sessionID: created.id, scoreText: "8", comment: "Bien")
        expect(current().averageScore == 8.5 && current().ratedCount == 2, "9 y 8: media 8,5")
        try await store.saveRating(trackID: tracks[2], sessionID: created.id, scoreText: "8", comment: "")
        expect(current().formattedAverage == (25.0 / 3).formatted(.number.precision(.fractionLength(0...2))),
               "9, 8 y 8: media 8,33")
        try await store.saveRating(trackID: tracks[2], sessionID: created.id, scoreText: "7,5", comment: "")
        expect(abs(current().averageScore! - 24.5 / 3) < 1e-9, "cambiar una nota recalcula la media")
        try await store.clearRating(trackID: tracks[2], sessionID: created.id)
        expect(current().averageScore == 8.5 && current().ratedCount == 2, "quitar una nota recalcula la media")
        expect(current().tracks[1].rating?.comment == "Bien", "conserva el comentario")

        // Una nota inválida no llega al servidor y no cambia nada.
        let calls = repo.ratingCalls
        do {
            try await store.saveRating(trackID: tracks[3], sessionID: created.id, scoreText: "10,5", comment: "")
            expect(false, "aceptó 10,5")
        } catch ReviewError.invalidScore {}
        expect(repo.ratingCalls == calls && current().ratedCount == 2, "nota inválida sin petición")

        // Si el servidor falla, la nota anterior se conserva: nunca se muestra un guardado falso.
        repo.error = ReviewError.accessDenied
        do {
            try await store.saveRating(trackID: tracks[0], sessionID: created.id, scoreText: "2", comment: "")
            expect(false, "mostró un guardado sin confirmación")
        } catch ReviewError.accessDenied {}
        expect(current().tracks[0].rating?.score.tenths == 90, "fallo del servidor conserva la nota")
        repo.error = URLError(.notConnectedToInternet)
        do {
            try await store.clearRating(trackID: tracks[0], sessionID: created.id)
            expect(false, "quitó la nota sin confirmación")
        } catch ReviewError.unavailable {}
        expect(current().tracks[0].rating != nil, "fallo al quitar conserva la nota")
        repo.error = nil

        // Reintentar la creación con el mismo id no duplica el álbum.
        _ = try await store.create(id: draftID, albumTitle: "Álbum", artistName: "Artista", trackList: "1\n2\n3\n4\n5")
        expect(store.sessions.count == 1 && repo.sessions.count == 1, "reintento sin duplicado")
        expect(current().ratedCount == 2, "el reintento conserva las notas")

        // Un fallo al recargar no borra los datos que ya se ven.
        repo.error = URLError(.timedOut)
        await store.load()
        expect(store.state == .ready && store.sessions.count == 1 && store.errorMessage != nil,
               "fallo al recargar conserva el historial")
        await store.delete(sessionID: created.id)
        expect(store.sessions.count == 1, "fallo al borrar conserva el álbum")
        repo.error = nil
        await store.delete(sessionID: created.id)
        expect(store.sessions.isEmpty && store.errorMessage == nil, "borrar el álbum")

        // Un error de carga inicial no parece un historial vacío.
        let failedRepo = FakeReviews()
        failedRepo.error = ReviewError.backendNotReady
        let failed = ReviewsStore(repository: failedRepo)
        await failed.load()
        expect(failed.state == .failed && failed.errorMessage == ReviewError.backendNotReady.errorDescription,
               "error de carga distinto de historial vacío")
        failedRepo.error = nil
        await failed.load()
        expect(failed.state == .ready, "reintentar la carga")

        // Decodificación de la respuesta de PostgREST, desordenada a propósito.
        let json = """
        {"id":"8F7C2B4E-1111-4000-8000-000000000001","album_title":"A","artist_name":"B",
         "created_at":"2026-09-28T10:00:00Z","session_tracks":[
          {"id":"8F7C2B4E-1111-4000-8000-000000000003","position":2,"title":"Dos","track_ratings":[]},
          {"id":"8F7C2B4E-1111-4000-8000-000000000002","position":1,"title":"Uno",
           "track_ratings":[{"score":8.3,"comment":null}]}]}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ListeningSession.self, from: Data(json.utf8))
        expect(decoded.tracks.map(\.title) == ["Uno", "Dos"], "canciones ordenadas por posición")
        expect(decoded.tracks[0].rating?.score.tenths == 83 && decoded.tracks[1].rating == nil, "notas decodificadas")
        expect(decoded.averageScore == 8.3, "media desde la respuesta")

        print("PASS: notas, media, validación, guardado, errores, reintentos y decodificación")
    }
}
