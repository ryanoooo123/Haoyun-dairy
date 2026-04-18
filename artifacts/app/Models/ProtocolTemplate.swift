import Foundation
import SwiftData

@Model
final class ProtocolTemplate {
    @Attribute(.unique) var id: UUID
    var name: String
    var kind: String
    var defaultDurationDays: Int

    @Relationship(deleteRule: .cascade, inverse: \Medication.protocolTemplate)
    var medications: [Medication] = []

    init(id: UUID = UUID(), name: String, kind: String, defaultDurationDays: Int) {
        self.id = id
        self.name = name
        self.kind = kind
        self.defaultDurationDays = defaultDurationDays
    }
}

enum ProtocolKind: String, CaseIterable, Identifiable {
    case ivf = "IVF"
    case fet = "FET"
    case iui = "IUI"

    var id: String { rawValue }

    var zhLabel: String {
        switch self {
        case .ivf: return "試管 IVF"
        case .fet: return "解凍植入 FET"
        case .iui: return "人工授精 IUI"
        }
    }

    var defaultDurationDays: Int {
        switch self {
        case .ivf: return 28
        case .fet: return 21
        case .iui: return 14
        }
    }
}
