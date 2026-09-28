import Foundation

@MainActor
final class FakeProfiles: ProfileRepository {
    var saved: Profile?
    var error: Error?
    var creates = 0
    var delay = false
    func load(userID: UUID) async throws -> Profile? {
        if let error { throw error }
        return saved
    }
    func create(_ input: ProfileInput) async throws -> Profile {
        creates += 1
        if delay { try await Task.sleep(for: .milliseconds(30)) }
        if let error { throw error }
        let profile = Profile(id: input.id, username: input.username,
                              displayName: input.displayName, createdAt: .now)
        saved = profile
        return profile
    }
}

@main struct ProfileTests {
    @MainActor static func main() async throws {
        let id = UUID()
        let valid = try ProfileInput(id: id, username: "  Jaime_R\n", displayName: " Jaime ")
        precondition(valid.username == "jaime_r" && valid.displayName == "Jaime")
        for username in ["ab", String(repeating: "a", count: 31), "name space", "josé", "name\nfoo", "👋"] {
            do {
                _ = try ProfileInput(id: id, username: username, displayName: "Valid")
                preconditionFailure("Accepted invalid username")
            } catch ProfileError.invalidUsername { }
        }
        for name in ["  ", String(repeating: "a", count: 51), "a\nb"] {
            do {
                _ = try ProfileInput(id: id, username: "valid", displayName: name)
                preconditionFailure("Accepted invalid display name")
            } catch ProfileError.invalidDisplayName { }
        }
        let repo = FakeProfiles()
        let store = ProfileStore(userID: id, repository: repo)
        await store.load()
        precondition(store.state == .needsProfile)
        await store.save(username: "ab", displayName: "Jaime")
        precondition(repo.creates == 0 && store.errorMessage != nil)
        repo.error = ProfileError.usernameTaken
        await store.save(username: "jaime", displayName: "Jaime")
        precondition(store.state == .needsProfile && !store.isSaving)
        precondition(store.errorMessage == ProfileError.usernameTaken.errorDescription)
        repo.error = nil
        repo.delay = true
        let first = Task { await store.save(username: "jaime", displayName: "Jaime") }
        await Task.yield()
        await store.save(username: "jaime", displayName: "Jaime")
        await first.value
        precondition(repo.creates == 2, "Only one extra request after the earlier failed request")
        precondition(store.state == .ready(repo.saved!))
        let reloaded = ProfileStore(userID: id, repository: repo)
        await reloaded.load()
        precondition(reloaded.state == .ready(repo.saved!))
        let failedRepo = FakeProfiles()
        failedRepo.error = ProfileError.backendNotReady
        let failed = ProfileStore(userID: UUID(), repository: failedRepo)
        await failed.load()
        precondition(failed.state == .failed, "An error must not look like an absent profile")
        failedRepo.error = nil
        await failed.load()
        precondition(failed.state == .needsProfile)
        print("PASS: validation, load, save, duplicate submissions, errors and retry")
    }
}
