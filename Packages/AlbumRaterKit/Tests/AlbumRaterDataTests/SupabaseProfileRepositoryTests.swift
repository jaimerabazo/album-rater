import AlbumRaterCore
import Foundation
import Testing
@testable import AlbumRaterData

@Suite("Repositorio de perfiles contra Supabase local", .enabled(if: LocalSupabase.isConfigured)) @MainActor
struct SupabaseProfileRepositoryTests {
    @Test func missingProfileIsNil() async throws {
        let (client, userID) = try await LocalSupabase.newAccount()
        #expect(try await SupabaseProfileRepository(client: client).load(userID: userID) == nil)
    }

    @Test func createAndLoad() async throws {
        let (client, userID) = try await LocalSupabase.newAccount()
        let repository = SupabaseProfileRepository(client: client)
        let username = LocalSupabase.uniqueUsername()
        let created = try await repository.create(ProfileInput(id: userID, username: username, displayName: "Jaime 👨‍💻"))
        #expect(created.id == userID)
        #expect(created.username == username)
        #expect(created.displayName == "Jaime 👨‍💻")
        #expect(try await repository.load(userID: userID) == created)
    }

    @Test("Si se perdió la respuesta, reintentar devuelve el perfil guardado")
    func retryReturnsExistingProfile() async throws {
        let (client, userID) = try await LocalSupabase.newAccount()
        let repository = SupabaseProfileRepository(client: client)
        let input = try ProfileInput(id: userID, username: LocalSupabase.uniqueUsername(), displayName: "A")
        let first = try await repository.create(input)
        #expect(try await repository.create(input) == first)
    }

    @Test func usernameTakenByAnotherAccount() async throws {
        let username = LocalSupabase.uniqueUsername()
        let (clientA, userA) = try await LocalSupabase.newAccount()
        _ = try await SupabaseProfileRepository(client: clientA)
            .create(ProfileInput(id: userA, username: username, displayName: "A"))

        let (clientB, userB) = try await LocalSupabase.newAccount()
        let repositoryB = SupabaseProfileRepository(client: clientB)
        await #expect(throws: ProfileError.usernameTaken) {
            _ = try await repositoryB.create(ProfileInput(id: userB, username: username, displayName: "B"))
        }
        #expect(try await repositoryB.load(userID: userA) == nil, "B no ve el perfil de A")
    }

    @Test("Crear el perfil de otra cuenta se rechaza")
    func cannotCreateOthersProfile() async throws {
        let (client, _) = try await LocalSupabase.newAccount()
        let (_, otherUser) = try await LocalSupabase.newAccount()
        await #expect(throws: ProfileError.accessDenied) {
            _ = try await SupabaseProfileRepository(client: client)
                .create(ProfileInput(id: otherUser, username: LocalSupabase.uniqueUsername(), displayName: "X"))
        }
    }

    @Test("Sin sesión no hay acceso")
    func anonymousAccessIsDenied() async throws {
        await #expect(throws: ProfileError.accessDenied) {
            _ = try await SupabaseProfileRepository(client: LocalSupabase.anonymousClient()).load(userID: UUID())
        }
    }
}
