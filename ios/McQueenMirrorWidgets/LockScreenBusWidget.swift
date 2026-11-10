import SwiftUI
import WidgetKit

/// Lock Screen widgets with the next bus.
struct LockScreenBusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: MirrorWidgetKind.lockScreenBus, provider: MirrorProvider()) { entry in
            LockScreenBusView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Next Bus")
        .description("When to leave for the next bus. Times are from the last refresh.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline])
    }
}

struct LockScreenBusView: View {
    @Environment(\.widgetFamily) private var family
    var entry: MirrorSnapshot

    var body: some View {
        let bus = entry.buses.first
        switch family {
        case .accessoryInline:
            if let bus {
                Label("\(bus.route) · leave \(bus.leave.clockTime)", systemImage: "bus.fill")
            } else {
                Label(entry.reachable ? "No buses" : "Mirror offline", systemImage: "bus.fill")
            }
        default:
            VStack(alignment: .leading, spacing: 0) {
                if let bus {
                    Label("\(bus.route) \(bus.headsign)", systemImage: "bus.fill")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Text("Leave \(bus.leave.clockTime)")
                        .font(.headline)
                        .monospacedDigit()
                    Text(laterLine(bus))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Label("Next bus", systemImage: "bus.fill")
                        .font(.caption.weight(.semibold))
                    Text(entry.reachable ? (entry.busMessage ?? "No bus times") : "Can't reach the mirror")
                        .font(.caption)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// The next two buses after this one, on any route, so a missed bus has a backup.
    /// Each gets its route when they aren't all on the same one.
    private func laterLine(_ bus: Bus) -> String {
        let later = (bus.then.map { (route: bus.route, leave: $0) } + entry.buses.dropFirst().map { (route: $0.route, leave: $0.leave) })
            .sorted { $0.leave < $1.leave }
            .prefix(2)
        guard !later.isEmpty else { return "Updated \(entry.fetched.clockTime)" }
        let mixed = later.contains { $0.route != bus.route }
        return "then " + later.map { mixed ? "\($0.route) \($0.leave.clockTime)" : $0.leave.clockTime }.joined(separator: ", ")
    }
}

#Preview(as: .accessoryRectangular) {
    LockScreenBusWidget()
} timeline: {
    MirrorSnapshot.sample
    MirrorSnapshot.offline
}

#Preview(as: .accessoryInline) {
    LockScreenBusWidget()
} timeline: {
    MirrorSnapshot.sample
}
