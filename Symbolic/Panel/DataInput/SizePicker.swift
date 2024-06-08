import SwiftUI

// MARK: - SizePicker

struct SizePicker: View {
    var body: some View {
        HStack {
            if isInputMode {
                content.onChange(of: inputSize) { onChange(inputSize) }
            } else {
                Menu {
                    Button { startInput() } label: { Text("Input") }
                } label: {
                    content
                }
                .tint(.label)
            }
        }
        .frame(height: 20)
        .padding(6)
        .background(Color.tertiarySystemBackground)
        .clipRounded(radius: 6)
    }

    init(size: CGSize,
         onChange: @escaping (CGSize) -> Void = { _ in },
         onDone: @escaping (CGSize) -> Void = { _ in })
    {
        self.size = size
        self.onChange = onChange
        self.onDone = onDone
    }

    // MARK: private

    private let size: CGSize
    private let onChange: (CGSize) -> Void
    private let onDone: (CGSize) -> Void

    @State private var isInputMode: Bool = false
    @State private var inputW: Double = 0
    @State private var inputH: Double = 0

    private var inputSize: CGSize { CGSize(inputW, inputH) }

    private var content: some View {
        HStack(spacing: 0) {
            if isInputMode {
                Button { endInput() } label: { Image(systemName: "checkmark.circle") }
            }
            Image(systemName: "arrow.left.and.right")
            if isInputMode {
                DecimalInput(title: "Width", inputNumber: $inputW)
            } else {
                Text(size.width.formatted(decimalFormatStyle()))
            }
            Rectangle().frame(width: 1).background(Color.label).padding(.horizontal, 4)
            Image(systemName: "arrow.up.and.down")
            if isInputMode {
                DecimalInput(title: "Height", inputNumber: $inputH)
            } else {
                Text(size.height.formatted(decimalFormatStyle()))
            }
        }
        .font(.footnote.monospacedDigit())
    }

    private func startInput() {
        isInputMode = true
        inputW = size.width
        inputH = size.height
    }

    private func endInput() {
        isInputMode = false
        onDone(inputSize)
    }
}
