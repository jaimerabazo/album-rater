import Foundation
import Supabase

enum Backend {
    // Publishable keys identify the project; they are safe to ship in an app.
    // Never put a secret or service_role key here: those bypass backend permissions.
    static func makeClient() -> SupabaseClient? {
        // En tests de UI nunca se usa el backend real: si el de pruebas no es válido, no hay backend.
        if ProcessInfo.processInfo.environment["ALBUM_RATER_UITEST_SUPABASE_URL"] != nil {
            #if DEBUG
            return uiTestingClient()
            #else
            return nil
            #endif
        }
        guard let file = Bundle.main.url(forResource: "BackendConfig", withExtension: "plist"),
              let data = try? Data(contentsOf: file),
              let config = try? PropertyListDecoder().decode(Configuration.self, from: data),
              let url = URL(string: config.SUPABASE_URL),
              url.scheme == "https", url.host != nil,
              !config.SUPABASE_URL.contains("YOUR_PROJECT"),
              config.SUPABASE_PUBLISHABLE_KEY.hasPrefix("sb_publishable_"),
              !config.SUPABASE_PUBLISHABLE_KEY.contains("REPLACE_ME") else {
            return nil
        }
        return SupabaseClient(
            supabaseURL: url,
            supabaseKey: config.SUPABASE_PUBLISHABLE_KEY,
            options: .init(auth: .init(
                storage: KeychainLocalStorage(service: "\(Bundle.main.bundleIdentifier ?? "AlbumRater").auth"),
                emitLocalSessionAsInitialSession: true
            ))
        )
    }

    private struct Configuration: Decodable {
        let SUPABASE_URL: String
        let SUPABASE_PUBLISHABLE_KEY: String
    }

    #if DEBUG
    /// Solo en Debug y solo hacia este Mac: los tests de UI apuntan la app al Supabase local
    /// (`supabase start`). Cada arranque usa un Keychain nuevo, así que empieza sin sesión.
    private static func uiTestingClient() -> SupabaseClient? {
        let environment = ProcessInfo.processInfo.environment
        guard let url = environment["ALBUM_RATER_UITEST_SUPABASE_URL"].flatMap(URL.init(string:)),
              ["127.0.0.1", "localhost"].contains(url.host()),
              let key = environment["ALBUM_RATER_UITEST_SUPABASE_KEY"] else {
            return nil
        }
        return SupabaseClient(
            supabaseURL: url,
            supabaseKey: key,
            options: .init(auth: .init(
                storage: KeychainLocalStorage(service: "AlbumRater.uitests.\(UUID().uuidString)"),
                emitLocalSessionAsInitialSession: true
            ))
        )
    }
    #endif
}
