import Foundation
import Observation
import Supabase

// One place for account state. SwiftUI updates when these properties change.
@MainActor @Observable
final class AuthStore {
    enum Step { case signIn, signUp, confirmEmail, resetEmail, confirmReset, newPassword }

    var step: Step = .signIn
    private(set) var user: User?
    private(set) var isRestoring = true
    private(set) var isBusy = false
    var message: String?
    var errorMessage: String?
    private var pendingEmail = ""
    let client: SupabaseClient?

    init(client: SupabaseClient?) {
        self.client = client
        if client == nil { isRestoring = false }
    }

    var isRecovering: Bool { step == .confirmReset || step == .newPassword }

    func observeSession() async {
        guard let client else { return }
        for await (event, session) in client.auth.authStateChanges {
            if Task.isCancelled { return }
            user = session?.user
            isRestoring = false
            if event == .passwordRecovery { step = .newPassword }
        }
    }

    func changeStep(_ newStep: Step) {
        step = newStep
        message = nil
        errorMessage = nil
    }

    func submit(email: String, password: String, code: String) async {
        guard let client, !isBusy else { return }
        isBusy = true
        errorMessage = nil
        message = nil
        defer { isBusy = false }
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            switch step {
            case .signIn:
                user = try await client.auth.signIn(email: email, password: password).user
            case .signUp:
                let result = try await client.auth.signUp(email: email, password: password)
                if let session = result.session {
                    user = session.user
                } else {
                    pendingEmail = email
                    step = .confirmEmail
                    message = "Check your email for a confirmation code. If you already have an account, return to log in."
                }
            case .confirmEmail:
                let result = try await client.auth.verifyOTP(email: pendingEmail, token: code, type: .signup)
                user = result.user
                step = .signIn
            case .resetEmail:
                try await client.auth.resetPasswordForEmail(email)
                pendingEmail = email
                step = .confirmReset
                message = "If an account exists for this email, you'll receive a recovery code."
            case .confirmReset:
                _ = try await client.auth.verifyOTP(email: pendingEmail, token: code, type: .recovery)
                step = .newPassword
            case .newPassword:
                user = try await client.auth.update(user: UserAttributes(password: password))
                step = .signIn
            }
        } catch {
            // Don't expose backend internals or log credentials.
            switch step {
            case .signIn:
                errorMessage = "Couldn't log in. Check your email, password, email confirmation, and connection."
            case .confirmEmail, .confirmReset:
                errorMessage = "Couldn't verify that code. It may be incorrect or expired. Try again or start over."
            default:
                errorMessage = "Couldn't complete this request. Check your connection and try again shortly."
            }
        }
    }

    func signOut() async {
        guard let client, !isBusy else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            try await client.auth.signOut(scope: .local)
            user = nil
            changeStep(.signIn)
        } catch {
            errorMessage = "Couldn't sign out. Please try again."
        }
    }
}
