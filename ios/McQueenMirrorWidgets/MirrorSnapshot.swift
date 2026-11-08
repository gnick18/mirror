import ImageIO
import UIKit
import WidgetKit

/// What a widget shows: one fetch from the mirror, replayed as the buses leave.
struct MirrorSnapshot: TimelineEntry {
    var date: Date
    var fetched: Date
    var reachable: Bool
    var busTitle: String?
    var buses: [Bus] = []
    var busMessage: String?  // why there are no buses to show
    var music: SpotifyStatus?
    var art: UIImage?
    var mode: DisplayMode?

    var mirrorOn: Bool { (mode ?? MirrorSettings.lastMode) != .off }

    static func fetch(music wantsMusic: Bool) async -> MirrorSnapshot {
        let now = Date()
        guard let client = try? MirrorClient.current(timeout: 8) else {
            return MirrorSnapshot(date: now, fetched: now, reachable: false)
        }
        async let state = try? client.state()
        async let report = try? client.buses()
        async let music = wantsMusic ? (try? client.spotify()) : nil
        let (s, r, m) = await (state, report, music)

        var snapshot = MirrorSnapshot(date: now, fetched: now, reachable: s != nil || r != nil, music: m, mode: s?.mode)
        if let mode = s?.mode { MirrorSettings.lastMode = mode }
        if let r {
            snapshot.busTitle = r.title
            snapshot.buses = r.buses
            snapshot.busMessage = message(for: r)
        }
        if let url = m?.playing?.artURL, let data = try? await client.download(url) {
            snapshot.art = thumbnail(data, maxPixels: 150)  // widgets have a tight memory limit
        }
        return snapshot
    }

    /// One entry now and one each time a bus leaves, for the next two hours, so the widget
    /// keeps dropping buses that have gone until iOS lets it fetch again.
    func timeline() -> Timeline<MirrorSnapshot> {
        let horizon = fetched.addingTimeInterval(2 * 3600)
        let leaves = buses.flatMap { [$0.leave] + $0.then }.filter { $0 > fetched && $0 < horizon }
        let dates = [fetched] + Set(leaves.map { $0.addingTimeInterval(60) }).sorted().prefix(16)
        let entries = dates.map { date in
            var entry = self
            entry.date = date
            entry.buses = buses.compactMap { $0.advanced(to: date) }.sorted { $0.leave < $1.leave }
            if entry.buses.isEmpty, !buses.isEmpty {
                entry.busMessage = "Open the app for newer times"
            }
            return entry
        }
        return Timeline(entries: entries, policy: .after(fetched.addingTimeInterval(15 * 60)))
    }

    private static func message(for report: BusReport) -> String? {
        if !report.configured { return "Bus times aren't set up" }
        if report.offHours == true { return "No bus times at this hour" }
        if let error = report.error { return error }
        if report.loading == true { return "Loading the timetable…" }
        if report.buses.isEmpty { return "No buses in the next 90 min" }
        return nil
    }

    private static func thumbnail(_ data: Data, maxPixels: Int) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary).map(UIImage.init(cgImage:))
    }
}

struct MirrorProvider: TimelineProvider {
    var music = true

    func placeholder(in context: Context) -> MirrorSnapshot { .sample }

    func getSnapshot(in context: Context, completion: @escaping (MirrorSnapshot) -> Void) {
        if context.isPreview {
            completion(.sample)
            return
        }
        Task { completion(await MirrorSnapshot.fetch(music: music)) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MirrorSnapshot>) -> Void) {
        Task { completion(await MirrorSnapshot.fetch(music: music).timeline()) }
    }
}

extension MirrorSnapshot {
    /// Made-up data for the widget gallery and previews.
    static var sample: MirrorSnapshot {
        let now = Date()
        func bus(_ route: String, _ color: String, _ headsign: String, in minutes: Double) -> Bus {
            let leave = now.addingTimeInterval(minutes * 60)
            return Bus(route: route, headsign: headsign, color: color, textColor: "#FFFFFF", stop: "Main St",
                       leave: leave, depart: leave.addingTimeInterval(240), arrive: leave.addingTimeInterval(1200),
                       live: true, then: [leave.addingTimeInterval(1800), leave.addingTimeInterval(3600)])
        }
        let track = Track(isPlaying: true, title: "Song Title", artist: "Artist", art: "", progress: 0, duration: 0,
                          device: "Mirror", volume: nil)
        return MirrorSnapshot(date: now, fetched: now, reachable: true, busTitle: "Next buses",
                              buses: [bus("2", "#333366", "Downtown", in: 6), bus("A", "#EE3325", "East Side", in: 13)],
                              music: SpotifyStatus(connected: true, detail: "", playing: track), mode: .auto)
    }

    static var offline: MirrorSnapshot {
        MirrorSnapshot(date: .now, fetched: .now, reachable: false)
    }
}
