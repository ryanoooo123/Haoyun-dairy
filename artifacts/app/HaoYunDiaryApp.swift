import SwiftUI
import SwiftData
import UserNotifications
import os

private let persistenceLogger = Logger(subsystem: "tw.haoyun.diary", category: "persistence")

@main
struct HaoYunDiaryApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var storeKit = StoreKitService()

    let modelContainer: ModelContainer?
    let persistenceDegraded: Bool
    let degradedMessage: String?

    init() {
        let schema = Schema([
            ProtocolTemplate.self,
            Medication.self,
            Cycle.self,
            DayEntry.self,
            Attempt.self,
            SubsidyRulesRecord.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        // Primary: on-disk persistence.
        if let container = Self.tryBuild(schema: schema, config: config, label: "primary") {
            self.modelContainer = container
            self.persistenceDegraded = false
            self.degradedMessage = nil
            return
        }

        // Fallback 1: in-memory with full schema; data will not persist between launches.
        let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        if let container = Self.tryBuild(schema: schema, config: fallbackConfig, label: "in-memory-full") {
            self.modelContainer = container
            self.persistenceDegraded = true
            self.degradedMessage = "資料庫初始化失敗，本次啟動將不會儲存資料"
            return
        }

        // Fallback 2: minimal in-memory container so the app launches in a degraded read-only mode.
        let minimalConfig = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            self.modelContainer = try ModelContainer(for: Attempt.self, configurations: minimalConfig)
            self.persistenceDegraded = true
            self.degradedMessage = "資料庫嚴重異常，功能將受限。請重新啟動或重新安裝 App。"
            persistenceLogger.error("Minimal in-memory ModelContainer used — app running in restricted mode.")
        } catch {
            // Absolute last resort: we cannot throw from an App initializer, and we will not crash.
            persistenceLogger.fault("Catastrophic ModelContainer failure: \(String(describing: error), privacy: .public)")
            if let fallback = Self.tryBuild(schema: Schema([Attempt.self]), config: minimalConfig, label: "minimal-retry") {
                self.modelContainer = fallback
            } else {
                // Bounded-retry emergency path (review R1 fix). May return nil — the WindowGroup
                // below renders a degraded splash when that happens.
                self.modelContainer = Self.emergencyContainer()
            }
            self.persistenceDegraded = true
            self.degradedMessage = "資料庫嚴重異常，功能將受限。請重新啟動或重新安裝 App。"
        }
    }

    private static func tryBuild(schema: Schema, config: ModelConfiguration, label: String) -> ModelContainer? {
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            persistenceLogger.error("ModelContainer build (\(label, privacy: .public)) failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    /// Bounded-retry emergency container (review R1 fix).
    /// Every attempt uses an in-memory ModelConfiguration (review R4 fix) so the emergency
    /// path can never contaminate on-disk state. Returns nil if all retries fail — the
    /// WindowGroup renders a degraded splash rather than hanging the main thread.
    private static func emergencyContainer() -> ModelContainer? {
        for attempt in 0..<3 {
            let cfg = ModelConfiguration(isStoredInMemoryOnly: true)
            if let container = try? ModelContainer(for: Attempt.self, configurations: cfg) {
                return container
            }
            persistenceLogger.error("emergencyContainer retry \(attempt) failed")
        }
        // One last try against an alternate model (in-memory only), then give up.
        let empty = ModelConfiguration(isStoredInMemoryOnly: true)
        if let container = try? ModelContainer(for: SubsidyRulesRecord.self, configurations: empty) {
            return container
        }
        persistenceLogger.fault("emergencyContainer exhausted all retries — returning nil; UI will render degraded splash.")
        return nil
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let container = modelContainer {
                    RootView()
                        .environmentObject(appState)
                        .environmentObject(storeKit)
                        .modelContainer(container)
                        .onAppear {
                            if persistenceDegraded, let msg = degradedMessage {
                                appState.persistenceDegraded = true
                                appState.presentError(msg)
                            }
                            SeedData.seedIfNeeded(container: container, appState: appState, degraded: persistenceDegraded)
                            Task { await storeKit.loadProducts() }
                        }
                } else {
                    DegradedSplashView()
                        .environmentObject(appState)
                        .onAppear {
                            appState.persistenceDegraded = true
                            appState.presentError("資料庫無法初始化，本次啟動將以唯讀模式執行")
                        }
                }
            }
        }
    }
}

/// Read-only splash shown when even the emergency ModelContainer path failed.
/// Does NOT attach `.modelContainer(...)` — any @Query in child views would crash,
/// so we keep this view free of SwiftData usage.
struct DegradedSplashView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
                .accessibilityHidden(true)
            Text("好孕日記")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("資料庫無法初始化")
                .font(.headline)
            Text("本次啟動將以唯讀模式執行。請重新啟動 App，若問題持續請重新安裝。")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("資料庫無法初始化，唯讀模式")
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var hasOnboarded: Bool
    @Published var notificationAuthorized: Bool = false
    @Published var lastError: String?
    /// True when persistence fell back to in-memory/restricted mode; views should block write actions.
    @Published var persistenceDegraded: Bool = false
    /// True when launched under XCUITest — skips onboarding gate to make test runs deterministic.
    let isUITestMode: Bool

    init() {
        let uiTest = ProcessInfo.processInfo.arguments.contains("-UITestMode")
        self.isUITestMode = uiTest
        if uiTest {
            // Deterministic UI-test starting point: pretend onboarding is done.
            self.hasOnboarded = true
            UserDefaults.standard.set(true, forKey: "haoyun.hasOnboarded")
        } else {
            self.hasOnboarded = UserDefaults.standard.bool(forKey: "haoyun.hasOnboarded")
        }
    }

    func completeOnboarding() {
        hasOnboarded = true
        UserDefaults.standard.set(true, forKey: "haoyun.hasOnboarded")
    }

    func refreshNotificationStatus() async {
        let status = await NotificationService.shared.currentAuthorizationStatus()
        await MainActor.run {
            self.notificationAuthorized = (status == .authorized || status == .provisional)
        }
    }

    func presentError(_ message: String) {
        self.lastError = message
    }
}

struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if appState.hasOnboarded {
                ContentView()
            } else {
                OnboardingView()
            }
        }
        .task {
            await appState.refreshNotificationStatus()
        }
        .overlay(alignment: .top) {
            if appState.persistenceDegraded {
                Text("資料庫處於受限模式，本次啟動的變更可能不會儲存")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange)
                    .cornerRadius(8)
                    .padding(.top, 4)
                    .accessibilityLabel("資料庫受限模式提醒")
            }
        }
        .alert("發生錯誤",
               isPresented: Binding(
                get: { appState.lastError != nil },
                set: { if !$0 { appState.lastError = nil } }
               ),
               presenting: appState.lastError
        ) { _ in
            Button("確定", role: .cancel) { appState.lastError = nil }
        } message: { msg in
            Text(msg)
        }
    }
}
