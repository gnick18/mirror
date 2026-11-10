import Foundation

/// Settings the app shares with its widgets through the app group.
enum MirrorSettings {
    static let appGroup = "group.com.grantnickles.McQueenMirror"
    static let defaults = UserDefaults(suiteName: appGroup) ?? .standard
    static let addressKey = "serverAddress"

    #if targetEnvironment(simulator)
    // The simulator runs on the Mac, which is where the dev server listens.
    static let defaultAddress = "http://127.0.0.1:8080"
    #else
    static let defaultAddress = "http://mirror.local:8080"
    #endif

    static var address: String {
        get { defaults.string(forKey: addressKey) ?? defaultAddress }
        set { defaults.set(newValue, forKey: addressKey) }
    }

    static var baseURL: URL? { url(from: address) }

    /// "mirror.local:8080" and "http://mirror.local:8080/" both become http://mirror.local:8080.
    static func url(from text: String) -> URL? {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return nil }
        if !s.contains("://") { s = "http://" + s }
        while s.hasSuffix("/") { s.removeLast() }
        guard let url = URL(string: s), let scheme = url.scheme, ["http", "https"].contains(scheme),
              let host = url.host(), !host.isEmpty else { return nil }
        return url
    }

    /// The display mode from the last time the app or a widget heard from the mirror.
    /// The Control Center toggle shows it when the mirror can't be reached.
    static var lastMode: DisplayMode? {
        get { defaults.string(forKey: "lastMode").flatMap(DisplayMode.init(rawValue:)) }
        set { defaults.set(newValue?.rawValue, forKey: "lastMode") }
    }
}
