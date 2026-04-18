import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState
    @Query(sort: \Attempt.erDate, order: .reverse) private var attempts: [Attempt]

    @State private var selectionMode: Bool = false
    /// Ordered list of selected attempt IDs (first-tapped goes into the left column, second-tapped into the right).
    /// Using an ordered Array (not Set) preserves user-intent selection order for CompareView (review B8 fix).
    @State private var selectedIDs: [UUID] = []
    @State private var showingCompare: Bool = false
    @State private var showingNewAttempt: Bool = false

    var body: some View {
        List {
            if attempts.isEmpty {
                Section {
                    Text("尚未新增任何療程紀錄")
                        .foregroundColor(.secondary)
                }
            } else {
                ForEach(attempts) { attempt in
                    attemptRow(attempt)
                }
                .onDelete(perform: deleteAttempts)
            }
        }
        .navigationTitle("療程歷程")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(selectionMode ? "完成" : "選取") {
                    selectionMode.toggle()
                    if !selectionMode { selectedIDs.removeAll() }
                }
                .accessibilityLabel(selectionMode ? "完成選取" : "進入選取模式")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingNewAttempt = true
                } label: {
                    Label("新增", systemImage: "plus")
                }
                .accessibilityLabel("新增療程紀錄")
            }
            ToolbarItem(placement: .bottomBar) {
                Button {
                    showingCompare = true
                } label: {
                    Label("比較所選", systemImage: "rectangle.split.2x1")
                }
                .disabled(selectedIDs.count < 2)
                .accessibilityLabel("比較所選療程")
            }
        }
        .sheet(isPresented: $showingNewAttempt) {
            // AttemptDetailView no longer has its own NavigationStack (review B2 fix),
            // so we wrap it here for modal (new-attempt) presentation.
            NavigationStack {
                AttemptDetailView(attempt: nil)
            }
        }
        .sheet(isPresented: $showingCompare) {
            // Resolve attempts in user-selection order, not Query order (review B8 fix).
            if selectedIDs.count >= 2,
               let left = attempts.first(where: { $0.id == selectedIDs[0] }),
               let right = attempts.first(where: { $0.id == selectedIDs[1] }) {
                CompareView(left: left, right: right)
            } else {
                // Safety fallback: show an empty placeholder if something went wrong.
                // Avoids a blank sheet with no dismiss affordance.
                VStack(spacing: 16) {
                    Text("請至少選擇兩筆療程紀錄進行比較。")
                        .font(.headline)
                    Button("關閉") { showingCompare = false }
                        .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
    }

    @ViewBuilder
    private func attemptRow(_ attempt: Attempt) -> some View {
        if selectionMode {
            Button {
                toggleSelection(attempt.id)
            } label: {
                HStack {
                    Image(systemName: selectedIDs.contains(attempt.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(.accentColor)
                        .accessibilityHidden(true)
                    attemptRowContent(attempt)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(attempt.protocolName)，\(selectionLabel(for: attempt.id))")
        } else {
            NavigationLink {
                AttemptDetailView(attempt: attempt)
            } label: {
                attemptRowContent(attempt)
            }
        }
    }

    private func selectionLabel(for id: UUID) -> String {
        guard let idx = selectedIDs.firstIndex(of: id) else { return "未選取" }
        return idx == 0 ? "已選取，第一項（左）" : "已選取，第二項（右）"
    }

    private func attemptRowContent(_ attempt: Attempt) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(attempt.protocolName.isEmpty ? "未命名療程" : attempt.protocolName)
                .font(.headline)
            HStack {
                Text("取卵：\(attempt.erDate.formatted(date: .abbreviated, time: .omitted))")
                Spacer()
                Text(AttemptOutcome(rawValue: attempt.outcome)?.zhLabel ?? attempt.outcome)
                    .foregroundColor(outcomeColor(attempt.outcome))
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func outcomeColor(_ outcome: String) -> Color {
        switch AttemptOutcome(rawValue: outcome) {
        case .positive: return .green
        case .negative: return .red
        default: return .secondary
        }
    }

    /// Toggle selection preserving insertion order. Caps to 2 selected; when a 3rd is tapped,
    /// the oldest selection (index 0) is evicted so the newest pair remains.
    private func toggleSelection(_ id: UUID) {
        if let existing = selectedIDs.firstIndex(of: id) {
            selectedIDs.remove(at: existing)
            return
        }
        if selectedIDs.count >= 2 {
            selectedIDs.removeFirst()
        }
        selectedIDs.append(id)
    }

    private func deleteAttempts(at offsets: IndexSet) {
        for index in offsets {
            let item = attempts[index]
            // Also drop from ordered selection if present, so selectedIDs can't reference deleted items.
            if let pos = selectedIDs.firstIndex(of: item.id) {
                selectedIDs.remove(at: pos)
            }
            modelContext.delete(item)
        }
        do {
            try modelContext.save()
        } catch {
            appState.presentError("刪除失敗：\(error.localizedDescription)")
        }
    }
}

#Preview {
    NavigationStack { HistoryView() }
        .environmentObject(AppState())
        .modelContainer(for: [ProtocolTemplate.self, Medication.self, Cycle.self, DayEntry.self, Attempt.self, SubsidyRulesRecord.self], inMemory: true)
}
