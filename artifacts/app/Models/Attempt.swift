import Foundation
import SwiftData

@Model
final class Attempt {
    @Attribute(.unique) var id: UUID
    var protocolName: String
    var doseTotal: String
    var erDate: Date
    var etDate: Date
    var betaHCG: Double
    var outcome: String
    var createdAt: Date

    var cycle: Cycle?

    init(
        id: UUID = UUID(),
        protocolName: String = "",
        doseTotal: String = "",
        erDate: Date = Date(),
        etDate: Date = Date(),
        betaHCG: Double = 0,
        outcome: String = AttemptOutcome.ongoing.rawValue,
        createdAt: Date = Date(),
        cycle: Cycle? = nil
    ) {
        self.id = id
        self.protocolName = protocolName
        self.doseTotal = doseTotal
        self.erDate = erDate
        self.etDate = etDate
        self.betaHCG = betaHCG
        self.outcome = outcome
        self.createdAt = createdAt
        self.cycle = cycle
    }
}

enum AttemptOutcome: String, CaseIterable, Identifiable {
    case ongoing = "ongoing"
    case positive = "positive"
    case negative = "negative"

    var id: String { rawValue }

    var zhLabel: String {
        switch self {
        case .ongoing: return "進行中"
        case .positive: return "成功"
        case .negative: return "未成功"
        }
    }
}
