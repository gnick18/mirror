import Foundation

// The portal server's JSON API (portal/server.py, bus.py and spotify.py).

struct MirrorState: Codable, Equatable {
    var mode: DisplayMode
    var hidden: [String]
    var simulate: Bool
    var someone: Bool
    var show: Bool
    var sensor: Sensor
    var version: String

    struct Sensor: Codable, Equatable {
        var connected: Bool
        var detail: String
    }

    func isShown(_ widget: MirrorWidgetID) -> Bool { !hidden.contains(widget.rawValue) }
}

enum DisplayMode: String, Codable, CaseIterable, Identifiable {
    case auto, on, off  // auto follows the presence sensor, off is a plain mirror

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: "Auto"
        case .on: "Always on"
        case .off: "Mirror only"
        }
    }

    var hint: String {
        switch self {
        case .auto: "Widgets show when someone is in front of the mirror."
        case .on: "Widgets always show."
        case .off: "Plain mirror. Widgets stay hidden."
        }
    }
}

/// The widgets the mirror itself can show or hide, in the order the remote lists them.
enum MirrorWidgetID: String, CaseIterable, Identifiable {
    case clock, weather, bus, music, agenda

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clock: "Clock"
        case .weather: "Weather"
        case .bus: "Bus times"
        case .music: "Now playing"
        case .agenda: "Calendar"
        }
    }
}

struct StatePatch: Encodable {
    var mode: DisplayMode?
    var hidden: [String]?
    var simulate: Bool?
    var reload: Bool?
}

struct SpotifyStatus: Codable, Equatable {
    var connected: Bool
    var detail: String
    var playing: Track?
}

struct Track: Codable, Equatable {
    var isPlaying: Bool
    var title: String
    var artist: String
    var art: String
    var progress: Int  // ms
    var duration: Int  // ms
    var device: String
    var volume: Int?

    var artURL: URL? { art.isEmpty ? nil : URL(string: art) }
}

enum SpotifyAction: String, Codable, CaseIterable, Sendable {
    case play, pause, next, previous, mirror
}

struct BusReport: Codable, Equatable {
    var configured: Bool
    var title: String?
    var offHours: Bool?
    var loading: Bool?
    var error: String?
    var note: String?
    var buses: [Bus]
}

/// One row per route: its next bus, plus the leave times of the two after it.
struct Bus: Codable, Equatable, Identifiable {
    var route: String
    var headsign: String
    var color: String
    var textColor: String
    var stop: String
    var leave: Date  // when to walk out the door
    var depart: Date  // when the bus leaves the stop
    var arrive: Date
    var live: Bool  // from a bus's own position rather than the timetable
    var then: [Date]

    var id: String { route }
}

enum MirrorError: LocalizedError {
    case badAddress
    case unreachable
    case server(String)

    var errorDescription: String? {
        switch self {
        case .badAddress: "The server address isn't valid. Check it in Settings."
        case .unreachable: "Can't reach the mirror"
        case .server(let message): message
        }
    }
}

/// The server's answer when something goes wrong, e.g. a 400 from /api/spotify.
private struct ServerFailure: Decodable {
    var error: String
}

struct MirrorClient {
    let baseURL: URL
    var timeout: TimeInterval = 6

    /// A client for the address saved in Settings.
    static func current(timeout: TimeInterval = 6) throws -> MirrorClient {
        guard let url = MirrorSettings.baseURL else { throw MirrorError.badAddress }
        return MirrorClient(baseURL: url, timeout: timeout)
    }

    func state() async throws -> MirrorState {
        try await send("api/state")
    }

    @discardableResult
    func update(_ patch: StatePatch) async throws -> MirrorState {
        let state: MirrorState = try await send("api/state", body: patch)
        MirrorSettings.lastMode = state.mode
        return state
    }

    func spotify() async throws -> SpotifyStatus {
        try await send("api/spotify")
    }

    func spotify(_ action: SpotifyAction) async throws {
        struct Command: Encodable { var action: SpotifyAction }
        struct Reply: Decodable { var ok: Bool? }
        let _: Reply = try await send("api/spotify", body: Command(action: action))
    }

    func buses() async throws -> BusReport {
        try await send("api/bus")
    }

    /// Album art and other files from outside the mirror.
    func download(_ url: URL) async throws -> Data {
        try await Self.session.data(for: URLRequest(url: url, timeoutInterval: timeout)).0
    }

    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.waitsForConnectivity = false
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601  // the server sends local times with an offset, e.g. 2026-11-08T09:49:23-06:00
        return d
    }()

    private func send<Reply: Decodable>(_ path: String) async throws -> Reply {
        try await perform(URLRequest(url: baseURL.appending(path: path), timeoutInterval: timeout))
    }

    private func send<Reply: Decodable>(_ path: String, body: some Encodable) async throws -> Reply {
        var request = URLRequest(url: baseURL.appending(path: path), timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        return try await perform(request)
    }

    private func perform<Reply: Decodable>(_ request: URLRequest) async throws -> Reply {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await Self.session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw MirrorError.unreachable
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let message = (try? JSONDecoder().decode(ServerFailure.self, from: data))?.error
            throw MirrorError.server(message ?? "The mirror answered with an error (\(status))")
        }
        do {
            return try Self.decoder.decode(Reply.self, from: data)
        } catch {
            throw MirrorError.server("The mirror sent a reply this app doesn't understand. Is the app up to date?")
        }
    }
}
