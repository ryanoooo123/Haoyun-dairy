import SwiftUI
import SwiftData

struct SubsidyEstimatorView: View {
    @EnvironmentObject var appState: AppState

    @State private var age: Int = 34
    @State private var attemptNumber: Int = 1
    @State private var outOfPocket: Int = 150_000
    @State private var showingShareSheet: Bool = false
    @State private var sharedPDFURL: URL?

    private var result: SubsidyCalculator.Result {
        SubsidyCalculator.compute(age: age, attempt: attemptNumber, outOfPocket: outOfPocket)
    }

    var body: some View {
        Form {
            Section("您的條件") {
                Stepper(value: $age, in: 20...50) {
                    HStack {
                        Text("年齡")
                        Spacer()
                        Text("\(age) 歲").foregroundColor(.secondary)
                    }
                    .accessibilityLabel("年齡 \(age) 歲")
                }
                Stepper(value: $attemptNumber, in: 1...10) {
                    HStack {
                        Text("療程次數")
                        Spacer()
                        Text("第 \(attemptNumber) 次").foregroundColor(.secondary)
                    }
                    .accessibilityLabel("療程第 \(attemptNumber) 次")
                }
                Stepper(value: $outOfPocket, in: 50_000...400_000, step: 10_000) {
                    HStack {
                        Text("本次預估花費")
                        Spacer()
                        Text("NT$\(outOfPocket.formatted())").foregroundColor(.secondary)
                    }
                    .accessibilityLabel("本次預估花費 \(outOfPocket) 元")
                }
            }

            Section("試算結果") {
                SubsidyResultCard(result: result)
            }

            Section {
                HStack {
                    Image(systemName: "info.circle")
                        .accessibilityHidden(true)
                    Text("Rules as of \(SubsidyRules.lastUpdatedLabel)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .accessibilityLabel("規則資料日期 \(SubsidyRules.lastUpdatedLabel)")
            }

            Section {
                Button(action: exportPDF) {
                    Label("匯出 PDF", systemImage: "square.and.arrow.up")
                }
                .accessibilityLabel("匯出 PDF")
            }
        }
        .navigationTitle("補助試算")
        .sheet(isPresented: $showingShareSheet) {
            if let url = sharedPDFURL {
                ShareSheet(items: [url])
            }
        }
    }

    private func exportPDF() {
        do {
            let url = try PDFExportService.exportSubsidyBreakdown(
                age: age,
                attempt: attemptNumber,
                outOfPocket: outOfPocket,
                result: result
            )
            sharedPDFURL = url
            showingShareSheet = true
        } catch {
            appState.presentError("PDF 匯出失敗：\(error.localizedDescription)")
        }
    }
}

struct SubsidyResultCard: View {
    let result: SubsidyCalculator.Result

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if result.exhausted {
                Label("已用完補助額度", systemImage: "exclamationmark.triangle")
                    .font(.headline)
                    .foregroundColor(.orange)
                    .accessibilityLabel("已用完補助額度")
            } else {
                HStack {
                    Text("補助上限")
                    Spacer()
                    Text("NT$\(result.subsidyCap.formatted())")
                        .fontWeight(.semibold)
                }
                HStack {
                    Text("實領補助")
                    Spacer()
                    Text("NT$\(result.actualSubsidy.formatted())")
                        .foregroundColor(.green)
                        .fontWeight(.semibold)
                }
                HStack {
                    Text("自費")
                    Spacer()
                    Text("NT$\(result.outOfPocketAfter.formatted())")
                        .fontWeight(.semibold)
                }
            }
            Text(result.explanation)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
        .accessibilityElement(children: .combine)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack { SubsidyEstimatorView() }
        .environmentObject(AppState())
}
