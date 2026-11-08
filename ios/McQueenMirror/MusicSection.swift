import SwiftUI

/// Spotify now playing, with the same controls as the web remote.
struct MusicSection: View {
    var music: SpotifyStatus?
    var hint: String
    var send: (SpotifyAction) -> Void

    var body: some View {
        if let music, music.connected {
            let track = music.playing
            HStack(spacing: 14) {
                AlbumArt(url: track?.artURL)
                VStack(alignment: .leading, spacing: 2) {
                    Text(track?.title ?? "Nothing playing")
                        .lineLimit(1)
                    Text(subtitle(music))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .listRowSeparator(.hidden)

            HStack(spacing: 28) {
                ControlButton(action: .previous, systemImage: "backward.fill", label: "Previous track", send: send)
                if track?.isPlaying == true {
                    ControlButton(action: .pause, systemImage: "pause.fill", label: "Pause", prominent: true, send: send)
                } else {
                    ControlButton(action: .play, systemImage: "play.fill", label: "Play", prominent: true, send: send)
                }
                ControlButton(action: .next, systemImage: "forward.fill", label: "Next track", send: send)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)

            Button("Play on the mirror's speakers") { send(.mirror) }
            if !hint.isEmpty {
                Text(hint)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text(music == nil ? "Can't reach the mirror" : "Spotify isn't connected")
                if let detail = music?.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func subtitle(_ music: SpotifyStatus) -> String {
        guard let track = music.playing else {
            return music.detail.isEmpty ? "Start Spotify on any speaker" : music.detail
        }
        return [track.artist, track.device.isEmpty ? "" : "on \(track.device)"].filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

private struct AlbumArt: View {
    var url: URL?

    var body: some View {
        AsyncImage(url: url) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            Image(systemName: "music.note")
                .foregroundStyle(.secondary)
        }
        .frame(width: 64, height: 64)
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

private struct ControlButton: View {
    var action: SpotifyAction
    var systemImage: String
    var label: String
    var prominent = false
    var send: (SpotifyAction) -> Void

    var body: some View {
        Button {
            send(action)
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: prominent ? 26 : 20))
                .frame(width: prominent ? 64 : 54, height: prominent ? 64 : 54)
                .foregroundStyle(prominent ? Color(.systemBackground) : Color.primary)
                .background(prominent ? Color.primary : Color(.tertiarySystemFill), in: Circle())
        }
        .buttonStyle(.plain)  // keep each button its own tap target inside the list row
        .accessibilityLabel(label)
    }
}
