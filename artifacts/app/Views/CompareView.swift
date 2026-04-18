import SwiftUI

struct CompareView: View {
    @Environment(\.dismiss) private var dismiss
    let left: Attempt
    let right: Attempt

    var body: some View {
        NavigationStack {
            ScrollView {
                HStack(alignment: .top, spacing: 12) {
                    column(for: left, title: "A")
                    column(for: right, title: "B")
                }
                .padding()
            }
            .navigationTitle("比較療程")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("關閉") { dismiss() }
                        .accessibilityLabel("關閉比較畫面")
                }
            }
        }
    }

    private func column(for attempt: Attempt, title: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            row("療程", attempt.protocolName)
            row("總劑量", attempt.doseTotal)
            row("取卵日", attempt.erDate.formatted(date: .abbreviated, time: .omitted))
            row("植入日", attempt.etDate.formatted(date: .abbreviated, time: .omitted))
            row("β-hCG", attempt.betaHCG == 0 ? "—" : String(format: "%.1f", attempt.betaHCG))
            row("結果", AttemptOutcome(rawValue: attempt.outcome)?.zhLabel ?? attempt.outcome)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("療程 \(title) 詳細資料")
    }

    private func row(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value.isEmpty ? "—" : value)
                .font(.body)
        }
    }
}
