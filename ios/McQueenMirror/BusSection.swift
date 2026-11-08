import SwiftUI

/// The next buses, one row per route. The title ("Next buses" or the one in config.json)
/// comes from the server.
struct BusSection: View {
    var report: BusReport?
    var error: String?

    var body: some View {
        Section {
            if let report {
                rows(report)
            } else if let error {
                Text(error).foregroundStyle(.secondary)
            } else {
                Text("Loading…").foregroundStyle(.secondary)
            }
        } header: {
            Text(report?.title ?? "Next buses")
        } footer: {
            if let note = report?.note {
                Text(note)
            }
        }
    }

    @ViewBuilder private func rows(_ report: BusReport) -> some View {
        if !report.configured {
            Text("Bus times aren't set up. Add a \"bus\" section to config.json on the mirror.")
                .foregroundStyle(.secondary)
        } else if report.offHours == true {
            Text("Bus times are off at this hour.")
                .foregroundStyle(.secondary)
        } else if let error = report.error {
            Text(error).foregroundStyle(.secondary)
        } else if report.loading == true {
            Text("Loading the timetable…").foregroundStyle(.secondary)
        } else if report.buses.isEmpty {
            Text("No buses in the next 90 minutes.").foregroundStyle(.secondary)
        } else {
            // Redraw every 15 seconds so "in N min" stays right between polls.
            TimelineView(.periodic(from: .now, by: 15)) { context in
                ForEach(report.buses.compactMap { $0.advanced(to: context.date.addingTimeInterval(-30)) }) { bus in
                    BusRow(bus: bus, now: context.date)
                }
            }
        }
    }
}

private struct BusRow: View {
    var bus: Bus
    var now: Date

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RouteBadge(bus: bus, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(bus.headsign)
                    .lineLimit(1)
                Group {
                    Text("Bus at \(bus.depart.clockTime) from \(bus.stop)")
                    if !bus.then.isEmpty {
                        // Like the mirror, later buses are given as the time to leave for them.
                        Text("Then leave \(bus.then.map(\.clockTime).joined(separator: ", "))")
                            .monospacedDigit()
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(minutes)
                    .font(.headline)
                    .monospacedDigit()
                HStack(spacing: 4) {
                    if bus.live {
                        Image(systemName: "dot.radiowaves.up.forward")
                            .foregroundStyle(.green)
                            .accessibilityLabel("Live")
                    }
                    Text("Leave \(bus.leave.clockTime)")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var minutes: String {
        let mins = Int(bus.leave.timeIntervalSince(now) / 60)
        return mins <= 0 ? "Leave now" : "in \(mins) min"
    }
}
