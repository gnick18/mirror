import Foundation
import Observation

/// What the remote knows about the mirror. Polls the server while the app is open, like
/// the web remote does, so it keeps up with the sensor and with other phones.
@MainActor @Observable
final class RemoteModel {
    enum Connection { case connecting, online, offline }

    private(set) var connection = Connection.connecting
    private(set) var state: MirrorState?
    private(set) var music: SpotifyStatus?
    private(set) var buses: BusReport?
    private(set) var busError: String?
    var musicHint = ""

    /// Polls until the task is cancelled (the app leaves the foreground or the address changes).
    func run() async {
        connection = .connecting
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.every(.seconds(2)) { await self.loadState() } }
            group.addTask { await self.every(.seconds(3)) { await self.loadMusic() } }
            group.addTask { await self.every(.seconds(30)) { await self.loadBuses() } }
        }
    }

    func refresh() async {
        async let s: Void = loadState()
        async let m: Void = loadMusic()
        async let b: Void = loadBuses()
        _ = await (s, m, b)
    }

    // MARK: - Display settings

    func setMode(_ mode: DisplayMode) {
        state?.mode = mode  // move the picker now, not after the round trip
        change(StatePatch(mode: mode))
    }

    func setShown(_ widget: MirrorWidgetID, _ shown: Bool) {
        guard let state else { return }
        let hidden = MirrorWidgetID.allCases.filter { $0 == widget ? !shown : !state.isShown($0) }.map(\.rawValue)
        self.state?.hidden = hidden
        change(StatePatch(hidden: hidden))
    }

    func setSimulate(_ on: Bool) {
        state?.simulate = on
        change(StatePatch(simulate: on))
    }

    func setRingLight(_ on: Bool) {
        state?.light = on
        change(StatePatch(light: on))
    }

    func reloadMirror() {
        change(StatePatch(reload: true))
    }

    private func change(_ patch: StatePatch) {
        Task {
            do {
                let client = try MirrorClient.current()
                state = try await client.update(patch)
                connection = .online
                if patch.mode != nil || patch.light != nil { reloadMirrorWidgets() }  // what the widgets and controls show
            } catch {
                await loadState()  // put the controls back to what the mirror really has
            }
        }
    }

    // MARK: - Music

    func spotify(_ action: SpotifyAction) {
        Task {
            do {
                try await MirrorClient.current().spotify(action)
                musicHint = ""
            } catch {
                musicHint = error.localizedDescription
            }
            try? await Task.sleep(for: .milliseconds(600))  // Spotify takes a moment to report the change
            await loadMusic()
            reloadMirrorWidgets()
        }
    }

    // MARK: - Loading

    private func loadState() async {
        do {
            state = try await MirrorClient.current().state()
            MirrorSettings.lastMode = state?.mode
            connection = .online
        } catch is CancellationError {
        } catch {
            connection = .offline
        }
    }

    private func loadMusic() async {
        do {
            music = try await MirrorClient.current().spotify()
        } catch is CancellationError {
        } catch {
            music = nil
        }
    }

    private func loadBuses() async {
        do {
            buses = try await MirrorClient.current(timeout: 20).buses()
            busError = nil
        } catch is CancellationError {
        } catch {
            busError = error.localizedDescription
        }
    }

    private func every(_ interval: Duration, _ work: @escaping () async -> Void) async {
        while !Task.isCancelled {
            await work()
            try? await Task.sleep(for: interval)
        }
    }
}
