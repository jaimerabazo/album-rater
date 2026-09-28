import Foundation

/// Nota de 1 a 10 con un decimal como máximo. Se guarda en décimas (85 = 8,5)
/// para que sumar y comparar sea exacto; Double no representa 0,1 con exactitud.
struct Score: Hashable, Comparable {
    static let range = 10...100

    let tenths: Int

    init?(tenths: Int) {
        guard Self.range.contains(tenths) else { return nil }
        self.tenths = tenths
    }

    /// Acepta «8,5» y «8.5»: el teclado decimal usa coma o punto según el idioma del iPhone.
    init?(parsing text: String) {
        let parts = text.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
            .split(separator: ".", omittingEmptySubsequences: false)
        func isDigits(_ part: Substring, count: ClosedRange<Int>) -> Bool {
            count.contains(part.count) && part.allSatisfy { ("0"..."9").contains($0) }
        }
        guard (1...2).contains(parts.count), isDigits(parts[0], count: 1...2),
              parts.count == 1 || isDigits(parts[1], count: 1...1),
              let whole = Int(parts[0]) else { return nil }
        let decimal = parts.count == 2 ? Int(parts[1])! : 0
        self.init(tenths: whole * 10 + decimal)
    }

    var value: Double { Double(tenths) / 10 }
    /// Exacto para enviarlo a PostgreSQL: 85 → 8.5.
    var decimalValue: Decimal { Decimal(tenths) / 10 }
    var formatted: String { value.formatted(.number.precision(.fractionLength(0...1))) }

    static func < (lhs: Score, rhs: Score) -> Bool { lhs.tenths < rhs.tenths }
}

extension Score: Decodable {
    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(Double.self)
        guard let score = Score(tenths: Int((value * 10).rounded())) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                    debugDescription: "Nota fuera de rango: \(value)"))
        }
        self = score
    }
}

struct TrackRating: Decodable, Equatable {
    let score: Score
    let comment: String?

    init(score: Score, comment: String) throws {
        let comment = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard comment.unicodeScalars.count <= 1000 else { throw ReviewError.invalidComment }
        self.score = score
        self.comment = comment.isEmpty ? nil : comment
    }
}

struct SessionTrack: Decodable, Identifiable, Equatable {
    let id: UUID
    let position: Int
    let title: String
    var rating: TrackRating?

    init(id: UUID, position: Int, title: String, rating: TrackRating? = nil) {
        self.id = id
        self.position = position
        self.title = title
        self.rating = rating
    }

    enum CodingKeys: String, CodingKey {
        case id, position, title
        case ratings = "track_ratings"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        position = try container.decode(Int.self, forKey: .position)
        title = try container.decode(String.self, forKey: .title)
        // PostgREST devuelve las notas como lista; RLS solo deja ver la propia.
        rating = try container.decode([TrackRating].self, forKey: .ratings).first
    }
}

struct ListeningSession: Decodable, Identifiable, Equatable {
    let id: UUID
    let albumTitle: String
    let artistName: String
    let createdAt: Date
    var tracks: [SessionTrack]

    init(id: UUID, albumTitle: String, artistName: String, createdAt: Date, tracks: [SessionTrack]) {
        self.id = id
        self.albumTitle = albumTitle
        self.artistName = artistName
        self.createdAt = createdAt
        self.tracks = tracks
    }

    enum CodingKeys: String, CodingKey {
        case id
        case albumTitle = "album_title"
        case artistName = "artist_name"
        case createdAt = "created_at"
        case tracks = "session_tracks"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        albumTitle = try container.decode(String.self, forKey: .albumTitle)
        artistName = try container.decode(String.self, forKey: .artistName)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        tracks = try container.decode([SessionTrack].self, forKey: .tracks).sorted { $0.position < $1.position }
    }

    var ratedCount: Int { tracks.count { $0.rating != nil } }

    /// Media de las canciones ya puntuadas; nil si todavía no hay ninguna.
    /// Es una propiedad calculada: cambia sola cada vez que cambia una nota.
    var averageScore: Double? {
        let scores = tracks.compactMap { $0.rating?.score.tenths }
        guard !scores.isEmpty else { return nil }
        return Double(scores.reduce(0, +)) / Double(scores.count) / 10
    }

    var formattedAverage: String? {
        averageScore?.formatted(.number.precision(.fractionLength(0...2)))
    }
}

// Los mismos límites se comprueban en PostgreSQL: la pantalla no es una barrera de seguridad.
struct NewSessionInput: Encodable, Equatable {
    let id: UUID
    let albumTitle: String
    let artistName: String
    let trackTitles: [String]

    // Nombres de los parámetros de create_listening_session.
    enum CodingKeys: String, CodingKey {
        case id = "p_id"
        case albumTitle = "p_album_title"
        case artistName = "p_artist_name"
        case trackTitles = "p_track_titles"
    }

    /// trackList contiene una canción por línea; las líneas vacías se ignoran.
    init(id: UUID, albumTitle: String, artistName: String, trackList: String) throws {
        guard let album = TextValidation.singleLine(albumTitle, length: 1...200) else {
            throw ReviewError.invalidAlbumTitle
        }
        guard let artist = TextValidation.singleLine(artistName, length: 1...200) else {
            throw ReviewError.invalidArtistName
        }
        let lines = trackList.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard (1...100).contains(lines.count) else { throw ReviewError.invalidTrackCount }
        let titles = try lines.enumerated().map { index, line in
            guard let title = TextValidation.singleLine(line, length: 1...200) else {
                throw ReviewError.invalidTrackTitle(position: index + 1)
            }
            return title
        }
        self.id = id
        self.albumTitle = album
        self.artistName = artist
        self.trackTitles = titles
    }

    static func trackCount(in trackList: String) -> Int {
        trackList.split(whereSeparator: \.isNewline)
            .count { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }
}

enum ReviewError: LocalizedError, Equatable {
    case invalidAlbumTitle, invalidArtistName, invalidTrackCount, invalidTrackTitle(position: Int)
    case invalidScore, invalidComment
    case backendNotReady, accessDenied, unavailable

    var errorDescription: String? {
        switch self {
        case .invalidAlbumTitle: "Escribe el título del álbum (hasta 200 caracteres)."
        case .invalidArtistName: "Escribe el nombre del artista (hasta 200 caracteres)."
        case .invalidTrackCount: "Añade entre 1 y 100 canciones, una por línea."
        case .invalidTrackTitle(let position): "Revisa la canción \(position): máximo 200 caracteres y sin tabuladores."
        case .invalidScore: "La nota debe estar entre 1 y 10, con un decimal como máximo (por ejemplo, 8,5)."
        case .invalidComment: "El comentario puede tener hasta 1000 caracteres."
        case .backendNotReady: "Las tablas de reviews aún no están disponibles. Aplica la migración de Supabase y reintenta."
        case .accessDenied: "No se ha podido acceder a tus reviews. Comprueba la sesión y los permisos de Supabase."
        case .unavailable: "No se ha podido confirmar la operación. Comprueba la conexión y reintenta."
        }
    }
}
