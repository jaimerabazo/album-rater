import SwiftUI

struct AuthView: View {
    @Bindable var auth: AuthStore
    @State private var email = ""
    @State private var password = ""
    @State private var repeatedPassword = ""
    @State private var code = ""

    private var needsEmail: Bool {
        [.signIn, .signUp, .resetEmail].contains(auth.step)
    }
    private var needsPassword: Bool {
        [.signIn, .signUp, .newPassword].contains(auth.step)
    }
    private var isNewPassword: Bool { auth.step == .signUp || auth.step == .newPassword }
    private var needsCode: Bool { auth.step == .confirmEmail || auth.step == .confirmReset }
    private var title: String {
        switch auth.step {
        case .signIn: "Log in"
        case .signUp: "Create account"
        case .confirmEmail: "Confirm your email"
        case .resetEmail: "Reset password"
        case .confirmReset: "Enter recovery code"
        case .newPassword: "Set a new password"
        }
    }
    private var canSubmit: Bool {
        (!needsEmail || (email.contains("@") && !email.trimmingCharacters(in: .whitespaces).isEmpty)) &&
        (!needsPassword || !password.isEmpty) &&
        (!isNewPassword || (password.count >= 12 && password == repeatedPassword)) &&
        (!needsCode || !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Listen together. Keep every first impression.")
                        .font(.title3)
                }
                Section(title) {
                    if needsEmail {
                        TextField("Email", text: $email)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    if needsPassword {
                        SecureField("Password", text: $password)
                            .textContentType(isNewPassword ? .newPassword : .password)
                        if isNewPassword {
                            SecureField("Repeat password", text: $repeatedPassword)
                                .textContentType(.newPassword)
                            Text("Use at least 12 characters.").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if needsCode {
                        TextField("Code from your email", text: $code)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                    }
                    if let message = auth.message { Text(message).foregroundStyle(.secondary) }
                    if let error = auth.errorMessage { Text(error).foregroundStyle(.red) }
                    Button {
                        Task {
                            await auth.submit(email: email, password: password,
                                              code: code.trimmingCharacters(in: .whitespacesAndNewlines))
                            password = ""
                            repeatedPassword = ""
                        }
                    } label: {
                        HStack {
                            Text(needsCode ? "Verify code" : title)
                            if auth.isBusy { ProgressView() }
                        }
                    }
                    .disabled(!canSubmit)
                }
                Section {
                    if auth.step == .signIn {
                        Button("Create an account") { auth.changeStep(.signUp) }
                        Button("Forgot password?") { auth.changeStep(.resetEmail) }
                    } else if auth.step == .newPassword {
                        Button("Cancel and sign out", role: .cancel) {
                            Task { await auth.signOut() }
                        }
                    } else {
                        Button("Back to log in") { auth.changeStep(.signIn) }
                    }
                }
            }
            .disabled(auth.isBusy)
            .navigationTitle("Album Rater")
            .onChange(of: auth.step) { _, _ in
                password = ""
                repeatedPassword = ""
                code = ""
            }
        }
    }
}
