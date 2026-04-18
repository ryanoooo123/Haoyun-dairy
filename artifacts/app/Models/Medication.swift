import Foundation
import SwiftData

@Model
final class Medication {
    @Attribute(.unique) var id: UUID
    var genericName: String
    var brandName: String
    var zhLabel: String
    var doseText: String
    var scheduledTime: Date

    var protocolTemplate: ProtocolTemplate?

    init(
        id: UUID = UUID(),
        genericName: String,
        brandName: String,
        zhLabel: String,
        doseText: String,
        scheduledTime: Date,
        protocolTemplate: ProtocolTemplate? = nil
    ) {
        self.id = id
        self.genericName = genericName
        self.brandName = brandName
        self.zhLabel = zhLabel
        self.doseText = doseText
        self.scheduledTime = scheduledTime
        self.protocolTemplate = protocolTemplate
    }

    var displayLabel: String {
        "\(zhLabel)（\(genericName) / \(brandName)）"
    }
}
