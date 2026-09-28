import Foundation
import Supabase

/// Conexión al Supabase local (`supabase start`). Los tests de integración solo se
/// ejecutan si existen estas variables; `scripts/test-data.sh` las rellena.
enum LocalSupabase {
    private static let environment = ProcessInfo.processInfo.environment
    static let url = environment["SUPABASE_TEST_URL"].flatMap(URL.init(string:))
    static let key = environment["SUPABASE_TEST_PUBLISHABLE_KEY"]
    static var isConfigured: Bool { url != nil && key != nil }

    /// Cliente sin sesión, como alguien que no ha iniciado sesión.
    static func anonymousClient() -> SupabaseClient {
        SupabaseClient(
            supabaseURL: url!,
            supabaseKey: key!,
            options: .init(auth: .init(storage: MemoryStorage(), emitLocalSessionAsInitialSession: true))
        )
    }

    /// Cuenta nueva y aislada para cada test. En local la confirmación por email está desactivada.
    static func newAccount() async throws -> (client: SupabaseClient, userID: UUID) {
        let client = anonymousClient()
        let email = "test-\(UUID().uuidString.lowercased())@example.com"
        let password = UUID().uuidString
        let response = try await client.auth.signUp(email: email, password: password)
        return (client, response.user.id)
    }

    static func uniqueUsername() -> String {
        "t_" + UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "").prefix(20)
    }
}

/// Guarda la sesión en memoria: los tests no tocan el Keychain.
/// @unchecked: el acceso al diccionario está protegido por el lock.
final class MemoryStorage: AuthLocalStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]

    func store(key: String, value: Data) throws { lock.withLock { values[key] = value } }
    func retrieve(key: String) throws -> Data? { lock.withLock { values[key] } }
    func remove(key: String) throws { _ = lock.withLock { values.removeValue(forKey: key) } }
}
