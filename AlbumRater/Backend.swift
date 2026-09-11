import Foundation
import Supabase

enum Backend {
    // Publishable keys identify the project; they are safe to ship in an app.
    // Never put a secret or service_role key here: those bypass backend permissions.
    static func makeClient() -> SupabaseClient? {
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
}
