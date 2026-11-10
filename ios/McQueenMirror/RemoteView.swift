import SwiftUI

/// The phone remote: the same controls as portal/web/remote.html, plus the next buses.
struct RemoteView: View {
    @State private var model = RemoteModel()
    @State private var showingSettings = false
    @AppStorage(MirrorSettings.addressKey, store: MirrorSettings.defaults) private var address = MirrorSettings.defaultAddress
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Mirror")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Settings", systemImage: "gearshape") { showingSettings = true }
                    }
                }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        // Poll only while the app is on screen, and start over when the address changes.
        .task(id: "\(scenePhase == .active) \(address)") {
            guard scenePhase == .active else { return }
            await model.run()
        }
    }

    @ViewBuilder private var content: some View {
        switch (model.connection, model.state) {
        case (.offline, _):
            OfflineView(address: address, retry: { await model.refresh() }, openSettings: { showingSettings = true })
        case (_, let state?):
            controls(state)
        default:
            ProgressView("Connecting to the mirror…")
        }
    }

    private func controls(_ state: MirrorState) -> some View {
        List {
            Section {
                StatusLine(state: state)
            }
            Section("Music") {
                MusicSection(music: model.music, hint: model.musicHint, send: model.spotify)
            }
            BusSection(report: model.buses, error: model.busError)
            Section {
                Picker("Display mode", selection: Binding(get: { state.mode }, set: model.setMode)) {
                    ForEach(DisplayMode.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowSeparator(.hidden)
                Text(state.mode.hint)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Toggle(isOn: Binding(get: { state.ringLight }, set: model.setRingLight)) {
                    Text("Ring light")
                    Text("Bright white border to light your face. Widgets hide while it's on.")
                }
            } header: {
                Text("Display")
            }
            Section("Widgets on the mirror") {
                ForEach(MirrorWidgetID.allCases) { widget in
                    Toggle(widget.title, isOn: Binding(get: { state.isShown(widget) }, set: { model.setShown(widget, $0) }))
                }
            }
            Section("Testing") {
                Toggle(isOn: Binding(get: { state.simulate }, set: model.setSimulate)) {
                    Text("Pretend someone's here")
                    Text(state.sensor.connected ? "Sensor connected, so this is ignored" : "Stands in for the sensor until it's wired")
                }
                .disabled(state.sensor.connected)
                Button("Reload the mirror", action: model.reloadMirror)
            }
        }
        .refreshable { await model.refresh() }
        .sensoryFeedback(.selection, trigger: state.mode)
    }
}

private struct StatusLine: View {
    var state: MirrorState

    var body: some View {
        let who = state.sensor.connected ? (state.someone ? "someone's here" : "nobody's here") : "no sensor"
        let showing = state.ringLight ? "Ring light on" : state.show ? "Showing widgets" : "Plain mirror"
        Label {
            Text("\(showing) · \(who)")
        } icon: {
            Circle()
                .fill(state.show || state.ringLight ? Color.green : Color.secondary)
                .frame(width: 10, height: 10)
        }
        .foregroundStyle(.secondary)
    }
}

private struct OfflineView: View {
    var address: String
    var retry: () async -> Void
    var openSettings: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Can't reach the mirror", systemImage: "wifi.exclamationmark")
        } description: {
            Text("Are you on your home Wi-Fi? The app looks for the mirror at \(address) and keeps trying.")
        } actions: {
            Button("Try Again") { Task { await retry() } }
                .buttonStyle(.borderedProminent)
            Button("Server Settings", action: openSettings)
        }
    }
}

#Preview {
    RemoteView()
}
