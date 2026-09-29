import AlbumRaterCore
import Foundation
import Supabase

@MainActor
public struct SupabaseProfileRepository: ProfileRepository {
    let client: SupabaseClient

    private static let columns = "id, username, display_name, created_at, is_private"

    public init(client: SupabaseClient) {
        self.client = client
    }

    public func load(userID: UUID) async throws -> Profile? {
        do {
            let profiles: [Profile] = try await client.from("profiles")
                .select(Self.columns)
                .eq("id", value: userID.uuidString)
                .limit(1)
                .execute().value
            return profiles.first
        } catch {
            throw map(error)
        }
    }

    public func create(_ input: ProfileInput) async throws -> Profile {
        do {
            // INSERT, no upsert: un reintento nunca debe sobrescribir un perfil existente.
            return try await client.from("profiles")
                .insert(input)
                .select(Self.columns)
                .single()
                .execute().value
        } catch let error as PostgrestError where error.code == "23505" {
            // La respuesta anterior pudo perderse después de guardarse el perfil.
            // Si ya existe el nuestro, lo recuperamos; si no, el username está ocupado.
            if let existing = try await load(userID: input.id) { return existing }
            throw ProfileError.usernameTaken
        } catch {
            throw map(error)
        }
    }

    public func setPrivacy(_ isPrivate: Bool, userID: UUID) async throws -> Profile {
        do {
            // .single(): si no es tu perfil, RLS no deja actualizar ninguna fila y la petición falla.
            return try await client.from("profiles")
                .update(["is_private": isPrivate])
                .eq("id", value: userID.uuidString)
                .select(Self.columns)
                .single()
                .execute().value
        } catch {
            throw map(error)
        }
    }

    private func map(_ error: Error) -> Error {
        guard let error = error as? PostgrestError else { return error }
        switch error.code {
        case "42P01", "PGRST205": return ProfileError.backendNotReady
        case "42501", "PGRST301", "PGRST302", "PGRST303": return ProfileError.accessDenied
        default: return ProfileError.unavailable
        }
    }
}
