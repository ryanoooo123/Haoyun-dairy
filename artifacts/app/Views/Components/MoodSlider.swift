import SwiftUI

struct MoodSlider: View {
    @Binding var value: Double

    private var emoji: String {
        switch Int(value) {
        case 1: return "😣"
        case 2: return "🙁"
        case 3: return "😐"
        case 4: return "🙂"
        default: return "😄"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(emoji)
                    .font(.largeTitle)
                    .accessibilityHidden(true)
                Spacer()
                Text("\(Int(value)) / 5")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            Slider(value: $value, in: 1...5, step: 1) {
                Text("心情")
            } minimumValueLabel: {
                Text("1").font(.caption)
            } maximumValueLabel: {
                Text("5").font(.caption)
            }
            .accessibilityLabel("心情評分")
            .accessibilityValue("\(Int(value)) / 5")
        }
    }
}

#Preview {
    MoodSlider(value: .constant(3))
        .padding()
}
