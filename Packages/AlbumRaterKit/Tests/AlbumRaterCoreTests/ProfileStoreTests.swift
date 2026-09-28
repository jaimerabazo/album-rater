import Foundation
import Testing
@testable import AlbumRaterCore

@Suite("Estado del perfil") @MainActor
struct ProfileStoreTests {
    let id = UUID()
    let repo = FakeProfiles()

    @Test func missingProfileAsksForOne() async {
        let store = ProfileStore(userID: id, repository: repo)
        #expect(store.state == .loading)
        await store.load()
        #expect(store.state == .needsProfile)
    }

    @Test func savedProfileIsRestored() async throws {
        repo.saved = Profile(id: id, username: "jaime", displayName: "Jaime", createdAt: .now)
        let store = ProfileStore(userID: id, repository: repo)
        await store.load()
        #expect(store.state == .ready(try #require(repo.saved)))
    }

    @Test("Un error de carga no parece un perfil vacío y se puede reintentar")
    func loadFailureCanRetry() async {
        repo.error = ProfileError.backendNotReady
        let store = ProfileStore(userID: id, repository: repo)
        await store.load()
        #expect(store.state == .failed)
        #expect(store.errorMessage == ProfileError.backendNotReady.errorDescription)
        repo.error = nil
        await store.load()
        #expect(store.state == .needsProfile)
        #expect(store.errorMessage == nil)
    }

    @Test("Errores desconocidos muestran un mensaje genérico")
    func unknownErrors() async {
        repo.error = URLError(.notConnectedToInternet)
        let store = ProfileStore(userID: id, repository: repo)
        await store.load()
        #expect(store.errorMessage == ProfileError.unavailable.errorDescription)
    }

    @Test func savesValidProfile() async throws {
        let store = ProfileStore(userID: id, repository: repo)
        await store.load()
        await store.save(username: " Jaime ", displayName: "Jaime")
        let saved = try #require(repo.saved)
        #expect(saved.username == "jaime")
        #expect(store.state == .ready(saved))
        #expect(!store.isSaving)
    }

    @Test("Una entrada inválida no llega al servidor")
    func invalidInputIsNotSent() async {
        let store = ProfileStore(userID: id, repository: repo)
        await store.load()
        await store.save(username: "ab", displayName: "Jaime")
        #expect(repo.creates == 0)
        #expect(store.errorMessage == ProfileError.invalidUsername.errorDescription)
        #expect(store.state == .needsProfile)
    }

    @Test("Username ocupado: conserva el formulario para reintentar")
    func usernameTaken() async {
        let store = ProfileStore(userID: id, repository: repo)
        await store.load()
        repo.error = ProfileError.usernameTaken
        await store.save(username: "jaime", displayName: "Jaime")
        #expect(store.state == .needsProfile)
        #expect(store.errorMessage == ProfileError.usernameTaken.errorDescription)
        #expect(!store.isSaving)
    }

    @Test("Solo guarda cuando falta el perfil")
    func saveRequiresNeedsProfile() async {
        let store = ProfileStore(userID: id, repository: repo)
        await store.save(username: "jaime", displayName: "Jaime")
        #expect(repo.creates == 0, "todavía está cargando")
    }

    @Test("Pulsar dos veces Guardar envía una sola petición")
    func duplicateSubmissions() async {
        let store = ProfileStore(userID: id, repository: repo)
        await store.load()
        repo.delay = .milliseconds(50)
        let first = Task { await store.save(username: "jaime", displayName: "Jaime") }
        await Task.yield()
        #expect(store.isSaving)
        await store.save(username: "jaime", displayName: "Jaime")
        await store.load()
        #expect(store.state == .needsProfile, "no recarga mientras guarda")
        await first.value
        #expect(repo.creates == 1)
        #expect(store.state == .ready(repo.saved!))
    }

    @Test("Cancelar la carga no muestra un error falso")
    func cancelledLoad() async {
        repo.delay = .seconds(10)
        let store = ProfileStore(userID: id, repository: repo)
        let task = Task { await store.load() }
        await Task.yield()
        task.cancel()
        await task.value
        #expect(store.state == .loading)
        #expect(store.errorMessage == nil)
    }

    @Test("Cancelar el guardado no muestra un error falso")
    func cancelledSave() async {
        let store = ProfileStore(userID: id, repository: repo)
        await store.load()
        repo.delay = .seconds(10)
        let task = Task { await store.save(username: "jaime", displayName: "Jaime") }
        await Task.yield()
        task.cancel()
        await task.value
        #expect(store.state == .needsProfile)
        #expect(store.errorMessage == nil)
        #expect(!store.isSaving)
    }
}
