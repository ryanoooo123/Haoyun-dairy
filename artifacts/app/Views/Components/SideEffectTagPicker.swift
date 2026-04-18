import SwiftUI

struct SideEffectTagPicker: View {
    @Binding var selected: Set<String>

    private let columns: [GridItem] = [
        GridItem(.adaptive(minimum: 90), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(SideEffectTag.allCases) { tag in
                Button {
                    toggle(tag.rawValue)
                } label: {
                    Text(tag.rawValue)
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selected.contains(tag.rawValue) ? Color.accentColor : Color.secondary.opacity(0.15))
                        .foregroundColor(selected.contains(tag.rawValue) ? .white : .primary)
                        .cornerRadius(20)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("副作用：\(tag.rawValue)")
                .accessibilityValue(selected.contains(tag.rawValue) ? "已選取" : "未選取")
                .accessibilityAddTraits(.isButton)
            }
        }
    }

    private func toggle(_ value: String) {
        if selected.contains(value) {
            selected.remove(value)
        } else {
            selected.insert(value)
        }
    }
}

#Preview {
    SideEffectTagPicker(selected: .constant(["頭痛"]))
        .padding()
}
