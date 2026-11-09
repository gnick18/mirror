import AppIntents
import SwiftUI
import WidgetKit

/// Medium home-screen widget: the next buses, with buttons for the ring light and for
/// turning the mirror's widgets on or off.
struct CommuteWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: MirrorWidgetKind.commute, provider: MirrorProvider()) { entry in
            CommuteView(entry: entry)
                .containerBackground(for: .widget) { Color.black }
        }
        .configurationDisplayName("Buses and Ring Light")
        .description("The next buses, with buttons for the ring light and the mirror's widgets. Times are from the last refresh.")
        .supportedFamilies([.systemMedium])
    }
}

struct CommuteView: View {
    var entry: MirrorSnapshot

    var body: some View {
        if entry.reachable {
            HStack(alignment: .top, spacing: 14) {
                BusColumn(entry: entry)
                    .frame(maxWidth: .infinity, alignment: .leading)
                VStack(spacing: 8) {
                    RingLightButton(on: entry.light)
                    MirrorButton(on: entry.mirrorOn)
                }
                .frame(width: 118)
            }
            .environment(\.colorScheme, .dark)
        } else {
            OfflineMessage(fetched: entry.fetched)
                .environment(\.colorScheme, .dark)
        }
    }
}

private struct BusColumn: View {
    var entry: MirrorSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.busTitle ?? "Next buses")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if entry.buses.isEmpty {
                Text(entry.busMessage ?? "No bus times")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(entry.buses.prefix(2)) { bus in
                HStack(spacing: 8) {
                    RouteBadge(bus: bus, size: 28)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Leave \(bus.leave.clockTime)")
                            .font(.headline)
                            .monospacedDigit()
                            .fixedSize()  // the time matters most, so the headsign gives way instead
                        Text([bus.then.first.map { "then \($0.clockTime)" }, bus.headsign].compactMap { $0 }.joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer(minLength: 0)
            // Widgets refresh when iOS allows, so say how old the times are.
            Text("Updated \(entry.fetched.clockTime)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

/// The ring light: the mirror's edge goes bright white and its widgets hide.
private struct RingLightButton: View {
    var on: Bool

    var body: some View {
        Button(intent: SetRingLightIntent(value: !on)) {
            VStack(spacing: 4) {
                Image(systemName: on ? "sun.max.fill" : "sun.max")
                    .font(.system(size: 24, weight: .semibold))
                Text("Ring light")
                    .font(.caption.weight(.semibold))
                Text(on ? "On" : "Off")
                    .font(.caption2)
                    .opacity(0.7)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(on ? .black : .white)
            .background(on ? Color.white : Color.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(on ? "Ring light on. Tap to turn it off." : "Ring light off. Tap to turn it on.")
        .invalidatableContent()
    }
}

/// Turns the mirror's widgets off (Mirror only) or back to Auto.
private struct MirrorButton: View {
    var on: Bool

    var body: some View {
        Button(intent: SetMirrorDisplayIntent(value: !on)) {
            HStack(spacing: 5) {
                Image(systemName: on ? "rectangle.portrait.inset.filled" : "rectangle.portrait")
                    .font(.system(size: 14))
                Text(on ? "Widgets on" : "Mirror only")
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 40)
            .foregroundStyle(on ? .black : .white)
            .background(on ? Color.green : Color.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(on ? "Mirror widgets on. Tap for Mirror only." : "Mirror only. Tap to turn widgets back on.")
        .invalidatableContent()
    }
}

struct OfflineMessage: View {
    var fetched: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Can't reach the mirror", systemImage: "wifi.exclamationmark")
                .font(.headline)
            Text("Are you on your home Wi-Fi?")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Text("Tried at \(fetched.clockTime)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

#Preview(as: .systemMedium) {
    CommuteWidget()
} timeline: {
    MirrorSnapshot.sample
    MirrorSnapshot.offline
}
