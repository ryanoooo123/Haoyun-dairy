import SwiftUI
import SwiftData

struct AttemptDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState

    let attempt: Attempt?

    @State private var protocolName: String = ""
    @State private var doseTotal: String = ""
    @State private var erDate: Date = Date()
    @State private var etDate: Date = Date()
    @State private var betaHCG: String = ""
    @State private var outcome: AttemptOutcome = .ongoing
    @State private var sharedPDFURL: URL?
    @State private var showingShareSheet: Bool = false

    var body: some View {
        // NOTE: No inner NavigationStack. This view is pushed from HistoryView via NavigationLink
        // (which already provides a NavigationStack), and when presented modally (new-attempt) the
        // caller wraps it in its own NavigationStack inside the .sheet.
        Form {
            Section("療程資訊") {
                TextField("療程名稱（如 IVF 標準長療程）", text: $protocolName)
                    .accessibilityLabel("療程名稱")
                TextField("總劑量（如 Gonal-F 2250 IU）", text: $doseTotal)
                    .accessibilityLabel("總劑量")
            }
            Section("關鍵日期") {
                DatePicker("取卵日", selection: $erDate, displayedComponents: .date)
                    .accessibilityLabel("取卵日")
                DatePicker("植入日", selection: $etDate, displayedComponents: .date)
                    .accessibilityLabel("植入日")
            }
            Section("結果") {
                TextField("Beta-hCG 數值", text: $betaHCG)
                    .keyboardType(.decimalPad)
                    .accessibilityLabel("Beta-hCG 數值")
                Picker("結果", selection: $outcome) {
                    ForEach(AttemptOutcome.allCases) { o in
                        Text(o.zhLabel).tag(o)
                    }
                }
                .accessibilityLabel("療程結果")
            }
            Section {
                Button(action: exportCycleCard) {
                    Label("匯出療程卡 PDF", systemImage: "doc.richtext")
                }
                .disabled(attempt == nil && protocolName.isEmpty)
                .accessibilityLabel("匯出療程卡 PDF")

                Button(action: bookConsultation) {
                    Label("預約諮詢（LINE / 網頁）", systemImage: "calendar.badge.plus")
                }
                .accessibilityLabel("預約諮詢")
            }
            Section {
                DisclaimerBanner()
            }
        }
        .navigationTitle(attempt == nil ? "新增療程" : "編輯療程")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("儲存") { save() }
                    .accessibilityLabel("儲存療程紀錄")
            }
        }
        .onAppear(perform: loadIfEditing)
        .sheet(isPresented: $showingShareSheet) {
            if let url = sharedPDFURL {
                ShareSheet(items: [url])
            }
        }
    }

    private func loadIfEditing() {
        guard let a = attempt else { return }
        protocolName = a.protocolName
        doseTotal = a.doseTotal
        erDate = a.erDate
        etDate = a.etDate
        betaHCG = a.betaHCG == 0 ? "" : String(a.betaHCG)
        outcome = AttemptOutcome(rawValue: a.outcome) ?? .ongoing
    }

    private func save() {
        let beta = Double(betaHCG) ?? 0
        let target: Attempt
        if let existing = attempt {
            target = existing
        } else {
            target = Attempt()
            modelContext.insert(target)
        }
        target.protocolName = protocolName
        target.doseTotal = doseTotal
        target.erDate = erDate
        target.etDate = etDate
        target.betaHCG = beta
        target.outcome = outcome.rawValue

        do {
            try modelContext.save()
            dismiss()
        } catch {
            appState.presentError("無法儲存：\(error.localizedDescription)")
        }
    }

    private func exportCycleCard() {
        let working = Attempt(
            protocolName: protocolName,
            doseTotal: doseTotal,
            erDate: erDate,
            etDate: etDate,
            betaHCG: Double(betaHCG) ?? 0,
            outcome: outcome.rawValue
        )
        do {
            let url = try PDFExportService.exportCycleCard(attempt: working)
            sharedPDFURL = url
            showingShareSheet = true
        } catch {
            appState.presentError("PDF 匯出失敗：\(error.localizedDescription)")
        }
    }

    private func bookConsultation() {
        Task {
            let success = await ClinicDeepLinkService.shared.openBookingLink()
            if !success {
                await MainActor.run {
                    appState.presentError("無法開啟預約連結，請稍後再試。")
                }
            }
        }
    }
}
