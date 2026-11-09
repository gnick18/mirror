import AppIntents
import WidgetKit

// Actions behind the widget buttons and the Control Center toggles. They're compiled into
// both the app and the widget extension, which is what WidgetKit asks for, and they also
// show up in the Shortcuts app.

enum MirrorWidgetKind {
    static let commute = "Commute"
    static let lockScreenBus = "LockScreenBus"
    static let displayControl = "com.grantnickles.McQueenMirror.DisplayControl"
    static let ringLightControl = "com.grantnickles.McQueenMirror.RingLightControl"
}

/// Refresh everything that shows the mirror's state, after a change from the app or a widget.
func reloadMirrorWidgets() {
    WidgetCenter.shared.reloadAllTimelines()
    ControlCenter.shared.reloadAllControls()
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

/// The ring light: the edge of the mirror goes bright white and the widgets hide.
struct SetRingLightIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Turn the Mirror's Ring Light On or Off"
    static let description = IntentDescription("Lights the edge of the mirror bright white and hides its widgets, or turns that off again.")

    @Parameter(title: "Ring light on")
    var value: Bool

    init() {}

    init(value: Bool) {
        self.value = value
    }

    func perform() async throws -> some IntentResult {
        defer { reloadMirrorWidgets() }
        try await MirrorClient.current().update(StatePatch(light: value))
        return .result()
    }
}
