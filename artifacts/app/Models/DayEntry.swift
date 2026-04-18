import Foundation
import SwiftData

@Model
final class DayEntry {
    @Attribute(.unique) var id: UUID
    var date: Date
    /// Legacy stored backing field. Never read or written by new code — retained only so
    /// existing on-disk SwiftData schemas keep migrating cleanly. The public source of
    /// truth for "was anything taken today" is the computed `injectionTaken` below,
    /// which derives its value from `takenMedicationIDsCSV`.
    var legacyInjectionTakenRaw: Bool
    var mood: Int
    var sideEffectTagsCSV: String
    var notes: String
    /// CSV of Medication.id UUID strings that were taken on this day.
    /// Enables per-medication checkmarks in TodayView (review B5 fix).
    /// This is the sole source of truth for taken state.
    var takenMedicationIDsCSV: String

    var cycle: Cycle?

    init(
        id: UUID = UUID(),
        date: Date,
        mood: Int = 3,
        sideEffectTagsCSV: String = "",
        notes: String = "",
        takenMedicationIDsCSV: String = "",
        cycle: Cycle? = nil
    ) {
        self.id = id
        self.date = date
        self.legacyInjectionTakenRaw = false
        self.mood = mood
        self.sideEffectTagsCSV = sideEffectTagsCSV
        self.notes = notes
        self.takenMedicationIDsCSV = takenMedicationIDsCSV
        self.cycle = cycle
    }

    /// Read-only aggregate indicator derived from `takenMedicationIDsCSV`.
    /// Making this computed (review R3 structural fix) makes it impossible for a view
    /// to write the legacy bool and diverge from the CSV source of truth.
    var injectionTaken: Bool {
        !takenMedicationIDsCSV.isEmpty
    }

    var sideEffectTags: [String] {
        get {
            sideEffectTagsCSV
                .split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        set {
            sideEffectTagsCSV = newValue.joined(separator: ",")
        }
    }

    // MARK: - Per-medication taken state (B5 fix — preserved verbatim)

    /// Parsed set of Medication UUIDs that have been taken on this day.
    private var takenMedicationIDSet: Set<UUID> {
        let ids = takenMedicationIDsCSV
            .split(separator: ",")
            .compactMap { UUID(uuidString: String($0).trimmingCharacters(in: .whitespaces)) }
        return Set(ids)
    }

    /// Returns true if the given medication has been marked taken on this day.
    func isTaken(medID: UUID) -> Bool {
        takenMedicationIDSet.contains(medID)
    }

    /// Toggles the taken state for a specific medication.
    /// The aggregate `injectionTaken` flag is now a computed property so no extra write is needed.
    func toggleTaken(medID: UUID) {
        var set = takenMedicationIDSet
        if set.contains(medID) {
            set.remove(medID)
        } else {
            set.insert(medID)
        }
        takenMedicationIDsCSV = set.map { $0.uuidString }.joined(separator: ",")
    }
}

enum SideEffectTag: String, CaseIterable, Identifiable {
    case headache = "頭痛"
    case bloating = "腹脹"
    case lowMood = "情緒低落"
    case insomnia = "失眠"
    case breastPain = "乳房脹痛"
    case nausea = "噁心"
    case fatigue = "疲倦"
    case bleeding = "出血"

    var id: String { rawValue }
}
