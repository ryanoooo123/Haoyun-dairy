import SwiftUI
import SwiftData

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var storeKit: StoreKitService
    @Query(sort: \ProtocolTemplate.name) private var protocolTemplates: [ProtocolTemplate]

    @State private var showingPaywall: Bool = false

    var body: some View {
        Form {
            Section("診所資訊") {
                HStack {
                    Text("LINE OA ID")
                    Spacer()
                    Text(ClinicDeepLinkService.shared.lineOAID.isEmpty ? "—" : ClinicDeepLinkService.shared.lineOAID)
                        .foregroundColor(.secondary)
                }
                .accessibilityElement(children: .combine)
                HStack {
                    Text("網頁預約")
                    Spacer()
                    Text(ClinicDeepLinkService.shared.webBookingURL.isEmpty ? "—" : ClinicDeepLinkService.shared.webBookingURL)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundColor(.secondary)
                }
                .accessibilityElement(children: .combine)
            }

            Section("升級") {
                Button {
                    showingPaywall = true
                } label: {
                    HStack {
                        Image(systemName: "star.circle.fill")
                            .foregroundColor(.pink)
                            .accessibilityHidden(true)
                        Text("升級 Premium")
                            .foregroundColor(.primary)
                        Spacer()
                        if storeKit.isPremium {
                            Text("已啟用")
                                .font(.caption)
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .accessibilityLabel("升級 Premium")
                .accessibilityHint(storeKit.isPremium ? "已啟用 Premium" : "點兩下開啟訂閱畫面")
            }

            Section("通知") {
                HStack {
                    Text("通知狀態")
                    Spacer()
                    Text(appState.notificationAuthorized ? "已啟用" : "未啟用")
                        .foregroundColor(appState.notificationAuthorized ? .green : .secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("通知狀態 \(appState.notificationAuthorized ? "已啟用" : "未啟用")")
            }

            Section("補助規則版本") {
                HStack {
                    Text("HPA 資料日期")
                    Spacer()
                    Text(SubsidyRules.lastUpdatedLabel)
                        .foregroundColor(.secondary)
                }
                .accessibilityElement(children: .combine)
            }

            Section("療程範本") {
                if protocolTemplates.isEmpty {
                    Text("尚未載入範本")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(protocolTemplates) { template in
                        HStack {
                            Text(template.name)
                            Spacer()
                            Text(template.kind)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Section("法律與聲明") {
                DisclaimerBanner()
                Link("衛福部 IVF 補助資訊", destination: URL(string: "https://www.hpa.gov.tw") ?? URL(fileURLWithPath: "/"))
                    .accessibilityLabel("開啟衛福部官方網站")
            }

            Section {
                Text("好孕日記 HaoYun Diary v1.0.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .navigationTitle("設定")
        .task {
            await appState.refreshNotificationStatus()
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
                .environmentObject(storeKit)
        }
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .environmentObject(AppState())
        .environmentObject(StoreKitService())
        .modelContainer(for: [ProtocolTemplate.self, Medication.self, Cycle.self, DayEntry.self, Attempt.self, SubsidyRulesRecord.self], inMemory: true)
}
