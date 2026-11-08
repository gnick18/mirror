import AppIntents
import WidgetKit

// Actions behind the widget buttons and the Control Center toggle. They're compiled into
// both the app and the widget extension, which is what WidgetKit asks for, and they also
// show up in the Shortcuts app.

enum MirrorWidgetKind {
    static let commute = "Commute"
    static let lockScreenBus = "LockScreenBus"
    static let displayControl = "com.grantnickles.McQueenMirror.DisplayControl"
}

/// Refresh everything that shows the mirror's state, after a change from the app or a widget.
func reloadMirrorWidgets() {
    WidgetCenter.shared.reloadAllTimelines()
    ControlCenter.shared.reloadControls(ofKind: MirrorWidgetKind.displayControl)
}

extension SpotifyAction: AppEnum {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Music action"
    static let caseDisplayRepresentations: [SpotifyAction: DisplayRepresentation] = [
        .play: "Play",
        .pause: "Pause",
        .next: "Next track",
        .previous: "Previous track",
        .mirror: "Play on the mirror's speakers",
    ]
}

struct SpotifyCommandIntent: AppIntent {
    static let title: LocalizedStringResource = "Control the Mirror's Music"
    static let description = IntentDescription("Plays, pauses or skips whatever Spotify is playing, through the mirror.")

    @Parameter(title: "Action")
    var action: SpotifyAction

    init() {}

    init(_ action: SpotifyAction) {
        self.action = action
    }

    func perform() async throws -> some IntentResult {
        defer { reloadMirrorWidgets() }
        try await MirrorClient.current().spotify(action)
        try? await Task.sleep(for: .milliseconds(700))  // Spotify takes a moment to report the change
        return .result()
    }
}

/// On goes back to Auto, so the presence sensor decides. Off is a plain mirror.
struct SetMirrorDisplayIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Turn the Mirror's Widgets On or Off"
    static let description = IntentDescription("Off switches the mirror to Mirror only. On goes back to Auto, so the presence sensor decides.")

    @Parameter(title: "Widgets on")
    var value: Bool

    init() {}

    init(value: Bool) {
        self.value = value
    }

    func perform() async throws -> some IntentResult {
        defer { reloadMirrorWidgets() }
        try await MirrorClient.current().update(StatePatch(mode: value ? .auto : .off))
        return .result()
    }
}
