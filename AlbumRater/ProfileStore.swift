import Foundation
import Observation

@MainActor
protocol ProfileRepository {
    func load(userID: UUID) async throws -> Profile?
    func create(_ input: ProfileInput) async throws -> Profile
}

@MainActor @Observable
final class ProfileStore {
    enum State: Equatable {
        case loading, needsProfile, ready(Profile), failed
    }

    private(set) var state: State = .loading
    private(set) var isSaving = false
    private(set) var errorMessage: String?
    private let userID: UUID
    private let repository: any ProfileRepository

    init(userID: UUID, repository: any ProfileRepository) {
        self.userID = userID
        self.repository = repository
    }

    func load() async {
        guard !isSaving else { return }
        state = .loading
        errorMessage = nil
        do {
            let profile = try await repository.load(userID: userID)
            try Task.checkCancellation()
            state = profile.map(State.ready) ?? .needsProfile
        } catch {
            guard !Task.isCancelled else { return }
            state = .failed
            errorMessage = message(for: error)
        }
    }

    func save(username: String, displayName: String) async {
        guard !isSaving, state == .needsProfile else { return }
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        do {
            let input = try ProfileInput(id: userID, username: username, displayName: displayName)
            let profile = try await repository.create(input)
            try Task.checkCancellation()
            state = .ready(profile)
        } catch {
            guard !Task.isCancelled else { return }
            // Conservamos el formulario y el texto para poder reintentar.
            errorMessage = message(for: error)
        }
    }

    private func message(for error: Error) -> String {
        (error as? ProfileError)?.errorDescription ?? ProfileError.unavailable.errorDescription!
    }
}
