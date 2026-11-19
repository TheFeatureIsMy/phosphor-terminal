import Foundation

enum IOSConfig {
    /// Simulator talks to the Mac host; a device build must override
    /// APIBaseURL in Info.plist (or a future runtime config screen).
    static var apiBaseURL: URL {
        if let override = UserDefaults.standard.string(forKey: "apiBaseURL"),
           let url = URL(string: override), !override.isEmpty {
            return url
        }
        if let raw = Bundle.main.object(forInfoDictionaryKey: "APIBaseURL") as? String,
           let url = URL(string: raw), !raw.isEmpty {
            return url
        }
        #if targetEnvironment(simulator)
        return URL(string: "http://127.0.0.1:8000")!
        #else
        return URL(string: "https://api.example.com")!
        #endif
    }
}
