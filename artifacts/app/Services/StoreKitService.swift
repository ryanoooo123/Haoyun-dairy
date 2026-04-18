import Foundation
import StoreKit
import os

/// Minimal StoreKit 2 scaffold powering the paywall. This is a non-gating service:
/// it loads products, lets users purchase / restore, and publishes transaction state.
/// No auto-subscribe, no sandbox bypass, no feature gating logic — those land later.
@MainActor
final class StoreKitService: ObservableObject {
    static let premiumYearlyProductID = "tw.haoyun.diary.premium.yearly"

    @Published var products: [Product] = []
    @Published var isPremium: Bool = false
    @Published var isLoading: Bool = false
    @Published var lastError: String?

    private let logger = Logger(subsystem: "tw.haoyun.diary", category: "storekit")
    private var transactionListenerTask: Task<Void, Never>?

    init() {
        transactionListenerTask = listenForTransactions()
    }

    deinit {
        transactionListenerTask?.cancel()
    }

    // MARK: - Product loading

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await Product.products(for: [Self.premiumYearlyProductID])
            self.products = loaded
            await refreshEntitlements()
        } catch {
            logger.error("loadProducts failed: \(String(describing: error), privacy: .public)")
            self.lastError = "無法載入訂閱資訊：\(error.localizedDescription)"
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async throws {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    self.isPremium = true
                case .unverified(_, let error):
                    logger.error("Unverified transaction: \(String(describing: error), privacy: .public)")
                    self.lastError = "交易驗證失敗，請稍後再試"
                }
            case .userCancelled:
                // Quiet no-op; user intent.
                break
            case .pending:
                self.lastError = "訂閱正在審核中，完成後將自動啟用"
            @unknown default:
                self.lastError = "未知的購買結果"
            }
        } catch {
            logger.error("purchase failed: \(String(describing: error), privacy: .public)")
            self.lastError = "購買失敗：\(error.localizedDescription)"
            throw error
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            logger.error("restore failed: \(String(describing: error), privacy: .public)")
            self.lastError = "恢復購買失敗：\(error.localizedDescription)"
        }
    }

    // MARK: - Entitlement refresh

    private func refreshEntitlements() async {
        var active = false
        for await verification in Transaction.currentEntitlements {
            if case .verified(let transaction) = verification,
               transaction.productID == Self.premiumYearlyProductID,
               transaction.revocationDate == nil {
                active = true
            }
        }
        self.isPremium = active
    }

    // MARK: - Transaction listener

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await verification in Transaction.updates {
                guard let self = self else { return }
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    await self.refreshEntitlements()
                case .unverified(_, let error):
                    await MainActor.run {
                        self.logger.error("Transaction update unverified: \(String(describing: error), privacy: .public)")
                    }
                }
            }
        }
    }
}
