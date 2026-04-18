import Foundation

enum SubsidyCalculator {
    struct Result {
        let subsidyCap: Int
        let actualSubsidy: Int
        let outOfPocketAfter: Int
        let exhausted: Bool
        let explanation: String
    }

    static func compute(age: Int, attempt: Int, outOfPocket: Int) -> Result {
        // HPA 2025 rules:
        // - Age < 40: up to 6 subsidized cycles. First cap NT$150k, subsequent NT$100k.
        // - Age 40-44: up to 3 subsidized cycles at NT$100k each.
        // - Age >= 45 or beyond limits: no subsidy.

        guard attempt >= 1 else {
            return Result(
                subsidyCap: 0,
                actualSubsidy: 0,
                outOfPocketAfter: outOfPocket,
                exhausted: true,
                explanation: "療程次數需為 1 次以上。"
            )
        }

        if age < 40 {
            if attempt > SubsidyRules.under40MaxCycles {
                return Result(
                    subsidyCap: 0,
                    actualSubsidy: 0,
                    outOfPocketAfter: outOfPocket,
                    exhausted: true,
                    explanation: "40 歲以下最多補助 \(SubsidyRules.under40MaxCycles) 次，您已超過上限。"
                )
            }
            let cap = attempt == 1 ? SubsidyRules.under40FirstCap : SubsidyRules.under40SubsequentCap
            let actual = min(cap, outOfPocket)
            return Result(
                subsidyCap: cap,
                actualSubsidy: actual,
                outOfPocketAfter: max(0, outOfPocket - actual),
                exhausted: false,
                explanation: attempt == 1
                    ? "40 歲以下第 1 次療程上限為 NT$\(cap.formatted())。"
                    : "40 歲以下第 2-6 次療程上限為 NT$\(cap.formatted())。"
            )
        } else if age <= 44 {
            if attempt > SubsidyRules.age40to44MaxCycles {
                return Result(
                    subsidyCap: 0,
                    actualSubsidy: 0,
                    outOfPocketAfter: outOfPocket,
                    exhausted: true,
                    explanation: "40-44 歲最多補助 \(SubsidyRules.age40to44MaxCycles) 次，您已超過上限。"
                )
            }
            let cap = SubsidyRules.age40to44Cap
            let actual = min(cap, outOfPocket)
            return Result(
                subsidyCap: cap,
                actualSubsidy: actual,
                outOfPocketAfter: max(0, outOfPocket - actual),
                exhausted: false,
                explanation: "40-44 歲每次療程上限為 NT$\(cap.formatted())（最多 \(SubsidyRules.age40to44MaxCycles) 次）。"
            )
        } else {
            return Result(
                subsidyCap: 0,
                actualSubsidy: 0,
                outOfPocketAfter: outOfPocket,
                exhausted: true,
                explanation: "45 歲以上依現行 HPA 規則無補助。"
            )
        }
    }
}
