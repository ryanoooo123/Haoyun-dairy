import SwiftUI
import SwiftData

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext

    @State private var selectedProtocol: ProtocolKind = .ivf
    @State private var age: Int = 34
    @State private var permissionRequested: Bool = false
    @State private var permissionLabel: String = "未啟用"
    @State private var isRequesting: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    protocolSection

                    ageSection

                    notificationSection

                    DisclaimerBanner()

                    Button(action: continueToApp) {
                        Text("開始記錄")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .accessibilityLabel("開始記錄")
                }
                .padding()
            }
            .navigationTitle("歡迎使用好孕日記")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("台灣試管療程的中文日記本")
                .font(.title3)
                .fontWeight(.semibold)
            Text("打針不漏、心情有靠、補助算得清。")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var protocolSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("療程類型")
                .font(.headline)
            Picker("療程類型", selection: $selectedProtocol) {
                ForEach(ProtocolKind.allCases) { kind in
                    Text(kind.zhLabel).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("療程類型選擇器")
        }
    }

    private var ageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("目前年齡")
                .font(.headline)
            Stepper(value: $age, in: 20...50) {
                Text("\(age) 歲")
                    .accessibilityLabel("年齡 \(age) 歲")
            }
        }
    }

    private var notificationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("提醒設定")
                .font(.headline)
            HStack {
                Text("通知狀態")
                Spacer()
                Text(permissionLabel)
                    .foregroundColor(appState.notificationAuthorized ? .green : .secondary)
                    .accessibilityLabel("通知狀態 \(permissionLabel)")
            }
            Button(action: requestPermission) {
                HStack {
                    if isRequesting { ProgressView() }
                    Text(isRequesting ? "處理中…" : "啟用打針提醒")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.secondary.opacity(0.15))
                .cornerRadius(10)
            }
            .disabled(isRequesting)
            .accessibilityLabel("啟用打針提醒")
        }
        .onAppear { updateLabel() }
        .onChange(of: appState.notificationAuthorized) { _, _ in updateLabel() }
    }

    private func updateLabel() {
        permissionLabel = appState.notificationAuthorized ? "已啟用" : "未啟用"
    }

    private func requestPermission() {
        isRequesting = true
        Task {
            do {
                let granted = try await NotificationService.shared.requestAuthorization()
                await MainActor.run {
                    appState.notificationAuthorized = granted
                    permissionRequested = true
                    isRequesting = false
                    updateLabel()
                }
            } catch {
                await MainActor.run {
                    appState.presentError("無法啟用通知：\(error.localizedDescription)")
                    isRequesting = false
                }
            }
        }
    }

    private func continueToApp() {
        // Ensure a Cycle exists for the user's first session.
        do {
            let existing = try modelContext.fetch(FetchDescriptor<Cycle>())
            if existing.isEmpty {
                let cycle = Cycle(
                    startDate: Calendar.current.startOfDay(for: Date()),
                    protocolKind: selectedProtocol.rawValue,
                    userAgeAtStart: age
                )
                modelContext.insert(cycle)
                try modelContext.save()
            }
        } catch {
            appState.presentError("無法建立週期：\(error.localizedDescription)")
            return
        }
        UserDefaults.standard.set(age, forKey: "haoyun.userAge")
        UserDefaults.standard.set(selectedProtocol.rawValue, forKey: "haoyun.protocolKind")
        appState.completeOnboarding()
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppState())
        .modelContainer(for: [ProtocolTemplate.self, Medication.self, Cycle.self, DayEntry.self, Attempt.self, SubsidyRulesRecord.self], inMemory: true)
}
