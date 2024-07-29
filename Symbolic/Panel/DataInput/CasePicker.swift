import SwiftUI

// MARK: - CasePicker

struct CasePicker<Value: Equatable & Hashable>: View {
    let cases: [Value]
    var value: Value
    var label: (Value) -> String = { "\($0)" }
    var onValue: (Value) -> Void

    var body: some View {
        content
    }
}

// MARK: private

private extension CasePicker {
    var font: Font { .caption2 }

    var opacity: Scalar { 0.5 }

    var padding: Scalar { 6 }

    @ViewBuilder var content: some View {
        HStack(spacing: 0) {
            ForEach(cases, id: \.self) { v in
                let selected = value == v
                Text(label(v))
                    .font(selected ? font.bold() : font)
                    .opacity(selected ? 1 : opacity)
                    .padding(.horizontal, padding)
                    .frame(maxHeight: .infinity)
                    .onTapGesture { onValue(v) }
                if v != cases.last {
                    Divider()
                        .padding(.vertical, padding)
                }
            }
        }
    }
}
