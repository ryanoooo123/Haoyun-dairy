import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject var storeKit: StoreKitService
    @Environment(\.dismiss) private var dismiss

    @State private var isPurchasing: Bool = false
    @State private var showingError: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    benefits
                    priceSection
                    actionButtons
                    disclaimer
                }
                .padding(20)
            }
            .navigationTitle("升級")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("關閉") { dismiss() }
                        .accessibilityLabel("關閉訂閱畫面")
                }
            }
            .alert("訂閱錯誤",
                   isPresented: Binding(
                    get: { storeKit.lastError != nil },
                    set: { if !$0 { storeKit.lastError = nil } }
                   ),
                   presenting: storeKit.lastError
            ) { _ in
                Button("確定", role: .cancel) { storeKit.lastError = nil }
            } message: { msg in
                Text(msg)
            }
            .onAppear {
                Task { await storeKit.loadProducts() }
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 56))
                .foregroundColor(.pink)
                .accessibilityHidden(true)
            Text("好孕日記 Premium")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("陪你走過每一次療程")
                .font(.title3)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("好孕日記 Premium，陪你走過每一次療程")
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 12) {
            benefitRow(icon: "chart.line.uptrend.xyaxis", text: "進階週期分析")
            benefitRow(icon: "square.stack.3d.up", text: "無限歷程比對")
            benefitRow(icon: "list.bullet.rectangle", text: "專屬療程指引")
        }
    }

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.pink)
                .frame(width: 32)
                .accessibilityHidden(true)
            Text(text)
                .font(.body)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
    }

    private var priceSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if storeKit.isLoading {
                ProgressView("載入訂閱資訊…")
                    .accessibilityLabel("載入訂閱資訊")
            } else if let product = storeKit.products.first {
                Text(product.displayPrice)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("\(product.displayName.isEmpty ? "年度訂閱" : product.displayName)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("尚未載入訂閱方案")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .accessibilityLabel("尚未載入訂閱方案")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(12)
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: subscribeTapped) {
                HStack {
                    if isPurchasing {
                        ProgressView()
                            .tint(.white)
                    }
                    Text("訂閱")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(storeKit.products.first == nil ? Color.gray : Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(storeKit.products.first == nil || isPurchasing)
            .accessibilityLabel("訂閱")

            Button(action: restoreTapped) {
                Text("恢復購買")
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.secondary.opacity(0.12))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
            }
            .accessibilityLabel("恢復購買")
        }
    }

    private var disclaimer: some View {
        Text("非醫療器材，請遵醫囑")
            .font(.footnote)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 8)
            .accessibilityLabel("本應用非醫療器材，請遵循醫師指示")
    }

    // MARK: - Actions

    private func subscribeTapped() {
        guard let product = storeKit.products.first else { return }
        isPurchasing = true
        Task {
            defer { Task { @MainActor in isPurchasing = false } }
            do {
                try await storeKit.purchase(product)
            } catch {
                // StoreKitService already surfaced the error via lastError; nothing more to do.
            }
        }
    }

    private func restoreTapped() {
        Task { await storeKit.restorePurchases() }
    }
}

#Preview {
    PaywallView()
        .environmentObject(StoreKitService())
}
