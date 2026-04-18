import SwiftUI

struct DisclaimerBanner: View {
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.shield.fill")
                .foregroundColor(.orange)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("本 App 不是醫療器材")
                    .font(.footnote)
                    .fontWeight(.semibold)
                Text("所有內容僅供紀錄參考，請依主治醫師指示用藥與決策。")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("This app is not a medical device. Consult your physician.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("免責聲明：本 App 不是醫療器材，請依主治醫師指示用藥與決策。")
    }
}

#Preview {
    DisclaimerBanner().padding()
}
