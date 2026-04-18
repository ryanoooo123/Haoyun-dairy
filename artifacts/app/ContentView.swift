import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            NavigationStack {
                TodayView()
            }
            .tabItem {
                Label("今日", systemImage: "sun.max")
            }
            .accessibilityLabel("今日")

            NavigationStack {
                CycleDiaryView()
            }
            .tabItem {
                Label("週期日記", systemImage: "calendar")
            }
            .accessibilityLabel("週期日記")

            NavigationStack {
                SubsidyEstimatorView()
            }
            .tabItem {
                Label("補助試算", systemImage: "dollarsign.circle")
            }
            .accessibilityLabel("補助試算")

            NavigationStack {
                HistoryView()
            }
            .tabItem {
                Label("歷程", systemImage: "clock.arrow.circlepath")
            }
            .accessibilityLabel("歷程")

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("設定", systemImage: "gearshape")
            }
            .accessibilityLabel("設定")
        }
        // NOTE: No `.alert(...)` here. RootView (HaoYunDiaryApp.swift) owns the single
        // appState.lastError presenter. Duplicating the alert here caused SwiftUI to
        // drop one and sometimes left alert state non-dismissable (review R2 fix).
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .modelContainer(for: [ProtocolTemplate.self, Medication.self, Cycle.self, DayEntry.self, Attempt.self, SubsidyRulesRecord.self], inMemory: true)
}
