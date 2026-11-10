import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft = MirrorSettings.address
    @State private var check: Check?

    enum Check: Equatable {
        case testing
        case ok(String)
        case failed(String)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(MirrorSettings.defaultAddress, text: $draft)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit(test)
                        .onChange(of: draft) { check = nil }
                    Button("Test Connection", action: test)
                        .disabled(check == .testing)
                    if let check {
                        CheckRow(check: check)
                    }
                } header: {
                    Text("Server address")
                } footer: {
                    Text("The mirror's portal on your home Wi-Fi. The app and its widgets only work at home, since the mirror isn't reachable from outside the house.")
                }
                if draft != MirrorSettings.defaultAddress {
                    Section {
                        Button("Use \(MirrorSettings.defaultAddress)") { draft = MirrorSettings.defaultAddress }
                    }
                }
                Section("Widgets") {
                    Text("iOS decides when widgets refresh, usually every 15 to 30 minutes, so they show a recent snapshot rather than live data. Bus times there are clock times from the last refresh. Open the app for live times.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(MirrorSettings.url(from: draft) == nil)
                }
            }
        }
    }

    private func save() {
        guard let url = MirrorSettings.url(from: draft) else { return }
        MirrorSettings.address = url.absoluteString
        reloadMirrorWidgets()
        dismiss()
    }

    private func test() {
        guard let url = MirrorSettings.url(from: draft) else {
            check = .failed("Enter an address like \(MirrorSettings.defaultAddress)")
            return
        }
        check = .testing
        Task {
            do {
                let state = try await MirrorClient(baseURL: url).state()
                check = .ok("Connected. \(state.show ? "The mirror is showing widgets." : "The mirror is a plain mirror right now.")")
            } catch MirrorError.unreachable {
                check = .failed("No answer from \(url.absoluteString). Are you on your home Wi-Fi, and is the server running?")
            } catch {
                check = .failed(error.localizedDescription)
            }
        }
    }
}

private struct CheckRow: View {
    var check: SettingsView.Check

    var body: some View {
        switch check {
        case .testing:
            HStack {
                ProgressView()
                Text("Testing…").foregroundStyle(.secondary)
            }
        case .ok(let message):
            Label(message, systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
    }
}

#Preview {
    SettingsView()
}
