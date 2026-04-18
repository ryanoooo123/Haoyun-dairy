import Foundation
import UIKit
import PDFKit

enum PDFExportError: LocalizedError {
    case writeFailed
    case renderFailed

    var errorDescription: String? {
        switch self {
        case .writeFailed: return "無法寫入 PDF 檔案。"
        case .renderFailed: return "PDF 產生失敗。"
        }
    }
}

enum PDFExportService {
    private static let pageSize = CGSize(width: 612, height: 792) // US Letter

    static func exportSubsidyBreakdown(
        age: Int,
        attempt: Int,
        outOfPocket: Int,
        result: SubsidyCalculator.Result
    ) throws -> URL {
        let data = try renderPDF { ctx in
            drawHeader(title: "好孕日記 · 補助試算")
            drawLine(y: 90)

            var y: CGFloat = 110
            drawRow(label: "年齡", value: "\(age) 歲", at: &y)
            drawRow(label: "療程次數", value: "第 \(attempt) 次", at: &y)
            drawRow(label: "本次預估花費", value: "NT$\(outOfPocket.formatted())", at: &y)
            y += 10
            drawLine(y: y); y += 15
            drawRow(label: "補助上限", value: result.exhausted ? "無" : "NT$\(result.subsidyCap.formatted())", at: &y)
            drawRow(label: "實領補助", value: "NT$\(result.actualSubsidy.formatted())", at: &y)
            drawRow(label: "自費金額", value: "NT$\(result.outOfPocketAfter.formatted())", at: &y)
            y += 20
            drawMultiline(result.explanation, at: &y, width: pageSize.width - 80)
            y += 10
            drawMultiline("資料依據：衛福部 HPA IVF 補助（\(SubsidyRules.lastUpdatedLabel) 版）", at: &y, width: pageSize.width - 80)
            drawFooter()
            _ = ctx
        }
        return try writeToTemp(data: data, filename: "subsidy_breakdown.pdf")
    }

    static func exportCycleCard(attempt: Attempt) throws -> URL {
        let data = try renderPDF { ctx in
            drawHeader(title: "好孕日記 · 療程卡")
            drawLine(y: 90)
            var y: CGFloat = 110
            drawRow(label: "療程名稱", value: attempt.protocolName.isEmpty ? "未命名" : attempt.protocolName, at: &y)
            drawRow(label: "總劑量", value: attempt.doseTotal.isEmpty ? "—" : attempt.doseTotal, at: &y)
            drawRow(label: "取卵日", value: attempt.erDate.formatted(date: .long, time: .omitted), at: &y)
            drawRow(label: "植入日", value: attempt.etDate.formatted(date: .long, time: .omitted), at: &y)
            drawRow(label: "β-hCG", value: attempt.betaHCG == 0 ? "—" : String(format: "%.2f", attempt.betaHCG), at: &y)
            drawRow(label: "結果", value: AttemptOutcome(rawValue: attempt.outcome)?.zhLabel ?? attempt.outcome, at: &y)
            y += 20
            drawLine(y: y); y += 15
            drawMultiline("本 App 不是醫療器材。This app is not a medical device. Consult your physician.", at: &y, width: pageSize.width - 80)
            drawFooter()
            _ = ctx
        }
        return try writeToTemp(data: data, filename: "cycle_card.pdf")
    }

    // MARK: - Drawing primitives

    private static func renderPDF(_ draw: (UIGraphicsPDFRendererContext) -> Void) throws -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        let data = renderer.pdfData { context in
            context.beginPage()
            draw(context)
        }
        guard !data.isEmpty else { throw PDFExportError.renderFailed }
        return data
    }

    private static func drawHeader(title: String) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 22),
            .foregroundColor: UIColor.label
        ]
        (title as NSString).draw(at: CGPoint(x: 40, y: 50), withAttributes: attrs)

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm"
        let dateStr = "產生時間：\(df.string(from: Date()))"
        let dateAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.secondaryLabel
        ]
        (dateStr as NSString).draw(at: CGPoint(x: 40, y: 78), withAttributes: dateAttrs)
    }

    private static func drawLine(y: CGFloat) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 40, y: y))
        path.addLine(to: CGPoint(x: pageSize.width - 40, y: y))
        UIColor.separator.setStroke()
        path.lineWidth = 0.5
        path.stroke()
    }

    private static func drawRow(label: String, value: String, at y: inout CGFloat) {
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.secondaryLabel
        ]
        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: UIColor.label
        ]
        (label as NSString).draw(at: CGPoint(x: 40, y: y), withAttributes: labelAttrs)
        (value as NSString).draw(at: CGPoint(x: 180, y: y - 1), withAttributes: valueAttrs)
        y += 26
    }

    private static func drawMultiline(_ text: String, at y: inout CGFloat, width: CGFloat) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.secondaryLabel
        ]
        let rect = CGRect(x: 40, y: y, width: width, height: 100)
        (text as NSString).draw(with: rect, options: [.usesLineFragmentOrigin], attributes: attrs, context: nil)
        y += 40
    }

    private static func drawFooter() {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9),
            .foregroundColor: UIColor.tertiaryLabel
        ]
        let text = "好孕日記 HaoYun Diary · 台中試管療程中文日記本"
        (text as NSString).draw(at: CGPoint(x: 40, y: pageSize.height - 40), withAttributes: attrs)
    }

    private static func writeToTemp(data: Data, filename: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            throw PDFExportError.writeFailed
        }
    }
}
