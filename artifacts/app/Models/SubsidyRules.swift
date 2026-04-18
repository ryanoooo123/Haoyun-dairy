import Foundation
import SwiftData

/// Persistent storage of current subsidy rule snapshot.
@Model
final class SubsidyRulesRecord {
    @Attribute(.unique) var id: UUID
    var lastUpdated: Date
    var under40MaxCycles: Int
    var under40FirstCap: Int
    var under40SubsequentCap: Int
    var age40to44MaxCycles: Int
    var age40to44Cap: Int

    init(
        id: UUID = UUID(),
        lastUpdated: Date,
        under40MaxCycles: Int,
        under40FirstCap: Int,
        under40SubsequentCap: Int,
        age40to44MaxCycles: Int,
        age40to44Cap: Int
    ) {
        self.id = id
        self.lastUpdated = lastUpdated
        self.under40MaxCycles = under40MaxCycles
        self.under40FirstCap = under40FirstCap
        self.under40SubsequentCap = under40SubsequentCap
        self.age40to44MaxCycles = age40to44MaxCycles
        self.age40to44Cap = age40to44Cap
    }
}

/// Default HPA 2025 snapshot. Source: https://www.hpa.gov.tw
struct SubsidyRules {
    static let lastUpdated: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 4
        components.day = 1
        return Calendar(identifier: .gregorian).date(from: components) ?? Date()
    }()

    static let under40MaxCycles: Int = 6
    static let under40FirstCap: Int = 150_000
    static let under40SubsequentCap: Int = 100_000
    static let age40to44MaxCycles: Int = 3
    static let age40to44Cap: Int = 100_000

    static var lastUpdatedLabel: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "zh_TW")
        df.dateFormat = "yyyy-MM"
        return df.string(from: lastUpdated)
    }
}
