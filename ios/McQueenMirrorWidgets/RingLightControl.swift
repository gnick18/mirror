import AppIntents
import SwiftUI
import WidgetKit

/// Control Center toggle for the ring light: the mirror's edge goes bright white and its
/// widgets hide.
struct RingLightControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: MirrorWidgetKind.ringLightControl, provider: Provider()) { isOn in
            ControlWidgetToggle("Ring Light", isOn: isOn, action: SetRingLightIntent()) { on in
                Label(on ? "On" : "Off", systemImage: on ? "sun.max.fill" : "sun.max")
            }
            .tint(.yellow)
        }
        .displayName("Ring Light")
        .description("Light the edge of the mirror bright white.")
    }

    struct Provider: ControlValueProvider {
        var previewValue: Bool { false }

        func currentValue() async throws -> Bool {
            // Away from home it shows as off. The mirror never keeps it on across a restart either.
            (try? await MirrorClient.current(timeout: 5).state())?.ringLight ?? false
        }
    }
}
