import AppIntents
import SwiftUI
import WidgetKit

/// Control Center toggle. Off switches the mirror to Mirror only. On goes back to Auto.
struct MirrorDisplayControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: MirrorWidgetKind.displayControl, provider: Provider()) { isOn in
            ControlWidgetToggle("Mirror", isOn: isOn, action: SetMirrorDisplayIntent()) { on in
                Label(on ? "Widgets on" : "Mirror only", systemImage: on ? "rectangle.portrait.inset.filled" : "rectangle.portrait")
            }
            .tint(.green)
        }
        .displayName("Mirror Widgets")
        .description("Switch the mirror between Auto and Mirror only.")
    }

    struct Provider: ControlValueProvider {
        var previewValue: Bool { true }

        func currentValue() async throws -> Bool {
            if let state = try? await MirrorClient.current(timeout: 5).state() {
                MirrorSettings.lastMode = state.mode
                return state.mode != .off
            }
            // Away from home: show the last thing we heard rather than failing.
            return MirrorSettings.lastMode != .off
        }
    }
}
