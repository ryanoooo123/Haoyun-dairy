import Foundation
import SwiftData
import os

private let seedLogger = Logger(subsystem: "tw.haoyun.diary", category: "seed")

enum SeedData {
    /// Seeds default protocol templates + medications once.
    /// - Parameters:
    ///   - container: the app's ModelContainer.
    ///   - appState: used to surface seed errors to the user.
    ///   - degraded: when true, persistence is in a restricted mode and writes will not persist; we still seed
    ///     an in-memory copy so feature F1 acceptance (≥4 seeded drugs visible) continues to hold.
    @MainActor
    static func seedIfNeeded(container: ModelContainer, appState: AppState? = nil, degraded: Bool = false) {
        let context = container.mainContext
        do {
            let existing = try context.fetch(FetchDescriptor<ProtocolTemplate>())
            if !existing.isEmpty { return }
        } catch {
            seedLogger.error("Failed to fetch existing ProtocolTemplate before seeding: \(String(describing: error), privacy: .public)")
            appState?.presentError("種子資料讀取失敗，將略過初始化。")
            return
        }

        let cal = Calendar.current
        let base = cal.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()

        let ivfTemplate = ProtocolTemplate(name: "IVF 標準長療程", kind: ProtocolKind.ivf.rawValue, defaultDurationDays: 28)
        let fetTemplate = ProtocolTemplate(name: "FET 解凍植入", kind: ProtocolKind.fet.rawValue, defaultDurationDays: 21)
        let iuiTemplate = ProtocolTemplate(name: "IUI 人工授精", kind: ProtocolKind.iui.rawValue, defaultDurationDays: 14)

        let meds: [(String, String, String, String, ProtocolTemplate)] = [
            ("follitropin alfa", "Gonal-F", "濾泡刺激素", "225 IU 皮下", ivfTemplate),
            ("menotropin", "Menopur", "尿促性腺激素", "75 IU 皮下", ivfTemplate),
            ("cetrorelix", "Cetrotide", "抑制排卵針", "0.25 mg 皮下", ivfTemplate),
            ("choriogonadotropin alfa", "Ovidrel", "破卵針", "250 mcg 皮下", ivfTemplate),
            ("estradiol valerate", "Progynova", "雌激素貼片/口服", "2 mg 每日兩次", fetTemplate),
            ("progesterone", "Crinone", "黃體素凝膠", "8% 每日一次", fetTemplate),
            ("clomiphene", "Clomid", "排卵藥", "50 mg 每日", iuiTemplate)
        ]

        // Track every object we insert so we can roll back on save failure.
        var inserted: [any PersistentModel] = []

        context.insert(ivfTemplate)
        inserted.append(ivfTemplate)
        context.insert(fetTemplate)
        inserted.append(fetTemplate)
        context.insert(iuiTemplate)
        inserted.append(iuiTemplate)

        var seededMeds: [Medication] = []
        for (generic, brand, zh, dose, template) in meds {
            let med = Medication(
                genericName: generic,
                brandName: brand,
                zhLabel: zh,
                doseText: dose,
                scheduledTime: base,
                protocolTemplate: template
            )
            context.insert(med)
            inserted.append(med)
            seededMeds.append(med)
        }

        do {
            try context.save()
            seedLogger.info("Seeded \(seededMeds.count, privacy: .public) medications across 3 protocol templates (degraded=\(degraded, privacy: .public))")
        } catch {
            seedLogger.error("Seed save failed: \(String(describing: error), privacy: .public). Rolling back \(inserted.count, privacy: .public) inserted objects so next launch retries cleanly.")
            // Roll back inserted objects so the next launch starts from a clean slate.
            for object in inserted {
                context.delete(object)
            }
            // Best-effort secondary save of the deletions; if this also fails we log and continue —
            // the in-memory context will be dropped at process exit anyway.
            do {
                try context.save()
            } catch {
                seedLogger.error("Rollback save failed: \(String(describing: error), privacy: .public)")
            }
            appState?.presentError("種子資料載入失敗，請重新啟動 App 再試一次。")
        }
    }
}
