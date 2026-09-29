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
        repo.saved = Profile(id: id, username: "jaime", displayName: "Jaime", createdAt: .now, isPrivate: false)
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

    // MARK: - Privacidad (M3.1)

    /// Store con el perfil ya guardado y cargado.
    private func readyStore() async -> ProfileStore {
        repo.saved = Profile(id: id, username: "jaime", displayName: "Jaime", createdAt: .now, isPrivate: false)
        let store = ProfileStore(userID: id, repository: repo)
        await store.load()
        return store
    }

    @Test("Pasar a privado y volver a público")
    func togglePrivacy() async throws {
        let store = await readyStore()
        await store.setPrivate(true)
        #expect(store.state == .ready(try #require(repo.saved)))
        #expect(repo.saved?.isPrivate == true)
        await store.setPrivate(false)
        #expect(repo.saved?.isPrivate == false)
        #expect(repo.privacyChanges == 2)
        #expect(!store.isSaving)
    }

    @Test("Elegir el valor que ya tiene no envía nada")
    func sameValueIsNotSent() async {
        let store = await readyStore()
        await store.setPrivate(false)
        #expect(repo.privacyChanges == 0)
    }

    @Test("Sin perfil cargado no se envía nada")
    func requiresLoadedProfile() async {
        let store = ProfileStore(userID: id, repository: repo)
        await store.setPrivate(true)
        #expect(repo.privacyChanges == 0)
    }

    @Test("Si el servidor falla, se conserva el valor anterior")
    func failureKeepsPreviousValue() async throws {
        let store = await readyStore()
        let before = store.state
        repo.error = ProfileError.accessDenied
        await store.setPrivate(true)
        #expect(store.state == before)
        #expect(store.errorMessage == ProfileError.accessDenied.errorDescription)
        #expect(!store.isSaving)
        repo.error = nil
        await store.setPrivate(true)
        #expect(store.errorMessage == nil, "reintentar limpia el error")
        #expect(repo.saved?.isPrivate == true)
    }

    @Test("Pulsar dos veces mientras guarda envía una sola petición")
    func duplicatePrivacyChanges() async {
        let store = await readyStore()
        repo.delay = .milliseconds(50)
        let first = Task { await store.setPrivate(true) }
        await Task.yield()
        await store.setPrivate(true)
        await first.value
        #expect(repo.privacyChanges == 1)
    }

    @Test("Cancelar el cambio no muestra un error falso")
    func cancelledPrivacyChange() async {
        let store = await readyStore()
        let before = store.state
        repo.delay = .seconds(10)
        let task = Task { await store.setPrivate(true) }
        await Task.yield()
        task.cancel()
        await task.value
        #expect(store.state == before)
        #expect(store.errorMessage == nil)
    }
}
