import Foundation

public struct Profile: Decodable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let username: String
    public let displayName: String
    public let createdAt: Date
    /// Privado: solo los seguidores aprobados verán su historial (M3.7). Público por defecto (D-005).
    public let isPrivate: Bool

    enum CodingKeys: String, CodingKey {
        case id, username
        case displayName = "display_name"
        case createdAt = "created_at"
        case isPrivate = "is_private"
    }
}

// Los mismos límites se comprueban en PostgreSQL: la pantalla no es una barrera de seguridad.
public struct ProfileInput: Encodable, Equatable, Sendable {
    public let id: UUID
    public let username: String
    public let displayName: String

    enum CodingKeys: String, CodingKey {
        case id, username
        case displayName = "display_name"
    }

    public init(id: UUID, username: String, displayName: String) throws {
        let username = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789_".unicodeScalars)
        guard (3...30).contains(username.utf8.count),
              username.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            throw ProfileError.invalidUsername
        }
        guard let name = TextValidation.singleLine(displayName, length: 1...50) else {
            throw ProfileError.invalidDisplayName
        }
        self.id = id
        self.username = username
        self.displayName = name
    }
}

public enum ProfileError: LocalizedError {
    case invalidUsername, invalidDisplayName, usernameTaken, backendNotReady, accessDenied, unavailable

    public var errorDescription: String? {
        switch self {
        case .invalidUsername: "Usa entre 3 y 30 caracteres: letras a–z, números o guion bajo."
        case .invalidDisplayName: "Escribe un nombre visible de 1 a 50 caracteres, sin saltos de línea."
        case .usernameTaken: "Ese nombre de usuario ya está en uso. Prueba con otro."
        case .backendNotReady: "La tabla de perfiles aún no está disponible. Aplica la migración de Supabase y reintenta."
        case .accessDenied: "No se ha podido acceder al perfil. Comprueba la sesión y los permisos de Supabase."
        case .unavailable: "No se ha podido confirmar la operación. Comprueba la conexión y reintenta."
        }
    }
}
