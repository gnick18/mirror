import AppIntents
import SwiftUI
import WidgetKit

/// Medium home-screen widget: the next buses beside what's playing, with buttons for
/// play/pause and for turning the mirror's widgets on or off.
struct CommuteWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: MirrorWidgetKind.commute, provider: MirrorProvider()) { entry in
            CommuteView(entry: entry)
                .containerBackground(for: .widget) { Color.black }
        }
        .configurationDisplayName("Bus and Music")
        .description("The next buses and what the mirror is playing. Times are from the last refresh.")
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
                MusicColumn(entry: entry)
                    .frame(width: 128)
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

private struct MusicColumn: View {
    var entry: MirrorSnapshot

    var body: some View {
        let music = entry.music
        let track = music?.playing
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Group {
                    if let art = entry.art {
                        Image(uiImage: art).resizable().scaledToFill()
                    } else {
                        Image(systemName: "music.note").foregroundStyle(.secondary)
                    }
                }
                .frame(width: 40, height: 40)
                .background(Color.white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title(music))
                        .font(.caption.weight(.semibold))
                        .lineLimit(2)
                    if let artist = track?.artist, !artist.isEmpty {
                        Text(artist)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                if music?.connected == true {
                    let playing = track?.isPlaying == true
                    Button(intent: SpotifyCommandIntent(playing ? .pause : .play)) {
                        Image(systemName: playing ? "pause.fill" : "play.fill")
                            .font(.system(size: 17))
                            .frame(width: 44, height: 44)
                            .foregroundStyle(.black)
                            .background(.white, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(playing ? "Pause" : "Play")
                    .invalidatableContent()
                }
                MirrorButton(on: entry.mirrorOn)
            }
        }
    }

    private func title(_ music: SpotifyStatus?) -> String {
        guard let music else { return "Music unavailable" }
        guard music.connected else { return "Spotify isn't connected" }
        return music.playing?.title ?? "Nothing playing"
    }
}

/// Turns the mirror's widgets off (Mirror only) or back to Auto.
private struct MirrorButton: View {
    var on: Bool

    var body: some View {
        Button(intent: SetMirrorDisplayIntent(value: !on)) {
            VStack(spacing: 1) {
                Image(systemName: on ? "rectangle.portrait.inset.filled" : "rectangle.portrait")
                    .font(.system(size: 16))
                Text(on ? "On" : "Off")
                    .font(.caption2.weight(.semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 44)
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
