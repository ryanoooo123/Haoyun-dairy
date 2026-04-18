import SwiftUI
import SwiftData

struct DayDetailSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState

    let cycle: Cycle
    let date: Date

    // Per-medication queue: we query all scheduled medications; filtering by date is
    // handled in the body via MedicationScheduleHelper.isScheduled(med:, on:).
    @Query(sort: \Medication.scheduledTime) private var medications: [Medication]

    @State private var mood: Double = 3
    @State private var selectedTags: Set<String> = []
    @State private var notes: String = ""
    @State private var takenIDs: Set<UUID> = []
    @State private var existingEntry: DayEntry?

    var body: some View {
        NavigationStack {
            Form {
                Section("日期") {
                    Text(date.formatted(date: .complete, time: .omitted))
                        .accessibilityLabel("選取日期 \(date.formatted(date: .long, time: .omitted))")
                }
                Section("打針 / 用藥") {
                    if scheduledMeds.isEmpty {
                        Text("當日無排定用藥")
                            .foregroundColor(.secondary)
                            .accessibilityLabel("當日無排定用藥")
                    } else {
                        ForEach(scheduledMeds) { med in
                            medicationRow(med)
                        }
                    }
                }
                Section("心情 (1-5)") {
                    MoodSlider(value: $mood)
                }
                Section("副作用") {
                    SideEffectTagPicker(selected: $selectedTags)
                }
                Section("備註") {
                    TextField("輸入備註…", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                        .accessibilityLabel("備註")
                }
            }
            .navigationTitle("當日記錄")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") { save() }
                        .accessibilityLabel("儲存")
                        .disabled(appState.persistenceDegraded)
                }
            }
            .onAppear(perform: loadExisting)
        }
    }

    /// Medications whose scheduled date falls on `date` (or, if none match, show all
    /// medications — covers seeded data where scheduledTime is a time-of-day anchor).
    private var scheduledMeds: [Medication] {
        let cal = Calendar.current
        let filtered = medications.filter { cal.isDate($0.scheduledTime, inSameDayAs: date) }
        return filtered.isEmpty ? medications : filtered
    }

    private func medicationRow(_ med: Medication) -> some View {
        let taken = takenIDs.contains(med.id)
        return Button {
            if taken {
                takenIDs.remove(med.id)
            } else {
                takenIDs.insert(med.id)
            }
        } label: {
            HStack {
                Image(systemName: taken ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(taken ? .green : .secondary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading) {
                    Text(med.displayLabel)
                        .font(.body)
                    Text(med.doseText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(med.scheduledTime, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("用藥：\(med.displayLabel)，\(taken ? "已完成" : "未完成")")
        .accessibilityHint("點兩下以切換打針狀態")
    }

    private func loadExisting() {
        let cal = Calendar.current
        if let e = cycle.dayEntries.first(where: { cal.isDate($0.date, inSameDayAs: date) }) {
            existingEntry = e
            mood = Double(e.mood)
            selectedTags = Set(e.sideEffectTags)
            notes = e.notes
            takenIDs = Set(
                e.takenMedicationIDsCSV
                    .split(separator: ",")
                    .compactMap { UUID(uuidString: String($0).trimmingCharacters(in: .whitespaces)) }
            )
        } else {
            mood = 3
            takenIDs = []
        }
    }

    private func save() {
        let entry: DayEntry
        if let existing = existingEntry {
            entry = existing
        } else {
            entry = DayEntry(date: Calendar.current.startOfDay(for: date), cycle: cycle)
            modelContext.insert(entry)
        }
        // Drive the canonical CSV directly; injectionTaken is now computed.
        entry.takenMedicationIDsCSV = takenIDs.map { $0.uuidString }.joined(separator: ",")
        entry.mood = Int(mood)
        entry.sideEffectTags = Array(selectedTags)
        entry.notes = notes

        do {
            try modelContext.save()
            dismiss()
        } catch {
            appState.presentError("無法儲存：\(error.localizedDescription)")
        }
    }
}
