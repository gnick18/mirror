import SwiftUI

extension Color {
    /// GTFS route colours, e.g. "#EE3325". Empty or malformed values fall back to grey.
    init(hex: String, fallback: Color = .gray) {
        let digits = hex.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else {
            self = fallback
            return
        }
        self.init(red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255, blue: Double(value & 0xFF) / 255)
    }
}

/// The route letter or number in its Metro colour, like the badge on the mirror.
struct RouteBadge: View {
    var bus: Bus
    var size: CGFloat = 30

    var body: some View {
        Text(bus.route)
            .font(.system(size: size * 0.55, weight: .bold, design: .rounded))
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .foregroundStyle(Color(hex: bus.textColor, fallback: .white))
            .frame(minWidth: size, minHeight: size)
            .padding(.horizontal, bus.route.count > 2 ? 4 : 0)
            .background(Color(hex: bus.color), in: RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
    }
}

extension Bus {
    /// This route as it will look at `date`: buses that have left are dropped and the next
    /// one moves up. Nil once all three have left. Later buses aren't marked live, because
    /// only the first one comes with its own prediction.
    func advanced(to date: Date) -> Bus? {
        if leave >= date { return self }
        let later = then.filter { $0 >= date }
        guard let next = later.first else { return nil }
        let shift = next.timeIntervalSince(leave)
        var bus = self
        bus.leave = next
        bus.depart = depart.addingTimeInterval(shift)
        bus.arrive = arrive.addingTimeInterval(shift)
        bus.then = Array(later.dropFirst())
        bus.live = false
        return bus
    }
}

extension Date {
    /// "9:49" or "21:49", following the phone's 12/24-hour setting, without AM/PM to save space.
    var clockTime: String {
        formatted(.dateTime.hour(.defaultDigits(amPM: .omitted)).minute())
    }
}
