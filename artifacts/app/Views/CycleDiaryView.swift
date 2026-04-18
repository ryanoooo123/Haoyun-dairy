import SwiftUI
import SwiftData

struct CycleDiaryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Cycle.startDate, order: .reverse) private var cycles: [Cycle]

    @State private var selectedDate: Date?

    private var currentCycle: Cycle? { cycles.first }

    private var daysInCycle: [Date] {
        guard let cycle = currentCycle else { return [] }
        let cal = Calendar.current
        let start = cal.startOfDay(for: cycle.startDate)
        let duration = max(14, ProtocolKind(rawValue: cycle.protocolKind)?.defaultDurationDays ?? 28)
        return (0..<duration).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    private let columns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let cycle = currentCycle {
                    Text("週期開始：\(cycle.startDate.formatted(date: .long, time: .omitted))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(daysInCycle, id: \.self) { day in
                            DayCell(
                                day: day,
                                cycleStartDate: cycle.startDate,
                                entry: cycle.dayEntries.first { Calendar.current.isDate($0.date, inSameDayAs: day) }
                            )
                            .onTapGesture { selectedDate = day }
                            .accessibilityAddTraits(.isButton)
                        }
                    }
                } else {
                    Text("尚未建立週期")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("週期日記")
        .sheet(item: Binding(
            get: { selectedDate.map { IdentifiableDate(date: $0) } },
            set: { selectedDate = $0?.date }
        )) { wrapper in
            if let cycle = currentCycle {
                DayDetailSheet(cycle: cycle, date: wrapper.date)
            }
        }
    }
}

struct IdentifiableDate: Identifiable {
    let date: Date
    var id: TimeInterval { date.timeIntervalSince1970 }
}

struct DayCell: View {
    let day: Date
    let cycleStartDate: Date
    let entry: DayEntry?

    private var dayNumber: Int {
        let cal = Calendar.current
        let start = cal.startOfDay(for: cycleStartDate)
        let target = cal.startOfDay(for: day)
        return (cal.dateComponents([.day], from: start, to: target).day ?? 0) + 1
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(day)
    }

    var body: some View {
        VStack(spacing: 4) {
            Text("D\(dayNumber)")
                .font(.caption2)
                .foregroundColor(.secondary)
            Text("\(Calendar.current.component(.day, from: day))")
                .font(.body)
                .fontWeight(isToday ? .bold : .regular)
            if let entry = entry, entry.injectionTaken {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
                    .accessibilityHidden(true)
            } else {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 12, height: 12)
            }
        }
        .frame(height: 64)
        .frame(maxWidth: .infinity)
        .background(isToday ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
        .cornerRadius(8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("第 \(dayNumber) 天 \(entry?.injectionTaken == true ? "已打針" : "未打針")")
    }
}

#Preview {
    NavigationStack { CycleDiaryView() }
        .modelContainer(for: [ProtocolTemplate.self, Medication.self, Cycle.self, DayEntry.self, Attempt.self, SubsidyRulesRecord.self], inMemory: true)
}
