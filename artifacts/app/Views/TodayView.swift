import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState

    @Query(sort: \Cycle.startDate, order: .reverse) private var cycles: [Cycle]
    @Query(sort: \Medication.scheduledTime) private var medications: [Medication]

    @State private var showingQuickLog: Bool = false

    private var currentCycle: Cycle? { cycles.first }

    private var todayDayNumber: Int {
        guard let cycle = currentCycle else { return 1 }
        return cycle.dayNumber(for: Date())
    }

    private var phase: Cycle.Phase {
        currentCycle?.phase(onDay: todayDayNumber) ?? .stimulation
    }

    private var shouldShowCopingCard: Bool {
        phase == .ovulation || phase == .twoWeekWait
    }

    private var todaysEntry: DayEntry? {
        guard let cycle = currentCycle else { return nil }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return cycle.dayEntries.first { cal.isDate($0.date, inSameDayAs: today) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                cycleHeader

                if shouldShowCopingCard {
                    MoodPromptCard(phase: phase)
                        .accessibilityLabel("心情提示卡")
                }

                todaysInjectionsSection

                quickLogButton

                Spacer(minLength: 20)
            }
            .padding()
        }
        .navigationTitle("今日")
        .sheet(isPresented: $showingQuickLog) {
            if let cycle = currentCycle {
                QuickLogSheet(cycle: cycle, date: Date())
            }
        }
    }

    private var cycleHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let cycle = currentCycle {
                Text("週期第 \(todayDayNumber) 天 · \(phase.rawValue)")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("療程：\(ProtocolKind(rawValue: cycle.protocolKind)?.zhLabel ?? cycle.protocolKind)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("尚未建立週期")
                    .font(.title2)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var todaysInjectionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今日用藥")
                .font(.headline)
            if medications.isEmpty {
                Text("尚未新增用藥")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(medications) { med in
                    medicationRow(med)
                }
            }
        }
    }

    private func medicationRow(_ med: Medication) -> some View {
        let taken = todaysEntry?.isTaken(medID: med.id) ?? false
        return Button {
            togglePerMedTaken(med: med)
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
            .padding(12)
            .background(Color.secondary.opacity(0.08))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .disabled(appState.persistenceDegraded || currentCycle == nil)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("用藥：\(med.displayLabel)，劑量 \(med.doseText)，\(taken ? "已完成" : "未完成")")
        .accessibilityHint("點兩下以切換打針狀態")
    }

    private func togglePerMedTaken(med: Medication) {
        guard let cycle = currentCycle else { return }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let entry: DayEntry
        if let existing = cycle.dayEntries.first(where: { cal.isDate($0.date, inSameDayAs: today) }) {
            entry = existing
        } else {
            let new = DayEntry(date: today, cycle: cycle)
            modelContext.insert(new)
            entry = new
        }
        entry.toggleTaken(medID: med.id)
        do {
            try modelContext.save()
        } catch {
            appState.presentError("無法儲存打針狀態：\(error.localizedDescription)")
        }
    }

    private var quickLogButton: some View {
        Button(action: { showingQuickLog = true }) {
            Label("快速記錄今日", systemImage: "square.and.pencil")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
        }
        .disabled(currentCycle == nil)
        .accessibilityLabel("快速記錄今日")
    }
}

struct MoodPromptCard: View {
    let phase: Cycle.Phase

    private var message: String {
        switch phase {
        case .ovulation:
            return "排卵期焦慮高峰。試試 4-7-8 呼吸：吸氣 4 秒、屏息 7 秒、吐氣 8 秒，重複 4 次。"
        case .twoWeekWait:
            return "兩週等待最煎熬。允許自己感受情緒，散步 15 分鐘、寫下三件感恩的事。"
        default:
            return "記得照顧自己。"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("今天好嗎？", systemImage: "heart.fill")
                .font(.headline)
                .foregroundColor(.pink)
            Text(message)
                .font(.body)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.pink.opacity(0.1))
        .cornerRadius(12)
    }
}

struct QuickLogSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState

    let cycle: Cycle
    let date: Date

    @Query(sort: \Medication.scheduledTime) private var medications: [Medication]

    @State private var mood: Double = 3
    @State private var selectedTags: Set<String> = []
    @State private var takenIDs: Set<UUID> = []
    @State private var existingEntry: DayEntry?

    var body: some View {
        NavigationStack {
            Form {
                Section("今日打針") {
                    if scheduledMeds.isEmpty {
                        Text("今日無排定用藥")
                            .foregroundColor(.secondary)
                            .accessibilityLabel("今日無排定用藥")
                    } else {
                        ForEach(scheduledMeds) { med in
                            medicationRow(med)
                        }
                    }
                }
                Section("心情") {
                    MoodSlider(value: $mood)
                }
                Section("副作用") {
                    SideEffectTagPicker(selected: $selectedTags)
                }
            }
            .navigationTitle("快速記錄")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") { save() }
                        .accessibilityLabel("儲存今日記錄")
                        .disabled(appState.persistenceDegraded)
                }
            }
            .onAppear(perform: loadExisting)
        }
    }

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
                Text(med.displayLabel)
                    .font(.body)
                Spacer()
                Text(med.scheduledTime, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("用藥：\(med.displayLabel)，\(taken ? "已完成" : "未完成")")
    }

    private func loadExisting() {
        let cal = Calendar.current
        if let e = cycle.dayEntries.first(where: { cal.isDate($0.date, inSameDayAs: date) }) {
            existingEntry = e
            mood = Double(e.mood)
            selectedTags = Set(e.sideEffectTags)
            takenIDs = Set(
                e.takenMedicationIDsCSV
                    .split(separator: ",")
                    .compactMap { UUID(uuidString: String($0).trimmingCharacters(in: .whitespaces)) }
            )
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
        // Write only the canonical CSV; injectionTaken is a computed property (R3 fix).
        entry.takenMedicationIDsCSV = takenIDs.map { $0.uuidString }.joined(separator: ",")
        entry.mood = Int(mood)
        entry.sideEffectTags = Array(selectedTags)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            appState.presentError("無法儲存：\(error.localizedDescription)")
        }
    }
}

#Preview {
    NavigationStack { TodayView() }
        .environmentObject(AppState())
        .modelContainer(for: [ProtocolTemplate.self, Medication.self, Cycle.self, DayEntry.self, Attempt.self, SubsidyRulesRecord.self], inMemory: true)
}
