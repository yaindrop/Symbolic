import SwiftUI

// MARK: - AnglePicker

struct AnglePicker: View {
    var body: some View {
        HStack {
            if isInputMode {
                content.onChange(of: inputAngle) { onChange(inputAngle) }
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

    init(angle: Angle,
         onChange: @escaping (Angle) -> Void = { _ in },
         onDone: @escaping (Angle) -> Void = { _ in })
    {
        self.angle = angle
        self.onChange = onChange
        self.onDone = onDone
        isRadians = false
    }

    // MARK: private

    private let angle: Angle
    private let onChange: (Angle) -> Void
    private let onDone: (Angle) -> Void

    @State private var isRadians: Bool
    @State private var isInputMode: Bool = false
    @State private var inputNumber: Double = 0

    private var angleValue: Double { isRadians ? angle.radians : angle.degrees }
    private var inputAngle: Angle { isRadians ? Angle(radians: inputNumber) : Angle(degrees: inputNumber) }

    private var content: some View {
        HStack(spacing: 0) {
            if isInputMode {
                Button { endInput() } label: { Image(systemName: "checkmark.circle") }
            }
            Image(systemName: "angle")
            if isInputMode {
                DecimalInput(title: isRadians ? "Radians" : "Degrees", inputNumber: $inputNumber)
            } else {
                Text(angleValue.formatted(decimalFormatStyle()))
            }
            Button {
                let angle = inputAngle
                isRadians.toggle()
                inputNumber = isRadians ? angle.radians : angle.degrees
            } label: { Text(isRadians ? "rad" : " ° ") }
        }
        .font(.footnote.monospacedDigit())
    }

    private func startInput() {
        isInputMode = true
        inputNumber = angle.degrees
    }

    private func endInput() {
        isInputMode = false
        onDone(inputAngle)
    }
}
