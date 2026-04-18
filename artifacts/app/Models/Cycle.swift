import Foundation
import SwiftData

@Model
final class Cycle {
    @Attribute(.unique) var id: UUID
    var startDate: Date
    var protocolKind: String
    var userAgeAtStart: Int

    @Relationship(deleteRule: .cascade, inverse: \DayEntry.cycle)
    var dayEntries: [DayEntry] = []

    var attempt: Attempt?

    init(
        id: UUID = UUID(),
        startDate: Date,
        protocolKind: String,
        userAgeAtStart: Int
    ) {
        self.id = id
        self.startDate = startDate
        self.protocolKind = protocolKind
        self.userAgeAtStart = userAgeAtStart
    }

    /// Day number within the cycle (Day 1 = startDate).
    func dayNumber(for date: Date, calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: startDate)
        let target = calendar.startOfDay(for: date)
        let components = calendar.dateComponents([.day], from: start, to: target)
        return (components.day ?? 0) + 1
    }

    enum Phase: String {
        case stimulation = "刺激期"
        case ovulation = "排卵期"
        case transfer = "植入期"
        case twoWeekWait = "等待期"
        case outcome = "結果期"
    }

    func phase(onDay day: Int) -> Phase {
        switch day {
        case ..<10: return .stimulation
        case 10...13: return .ovulation
        case 14...16: return .transfer
        case 17...28: return .twoWeekWait
        default: return .outcome
        }
    }
}
