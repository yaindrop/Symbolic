import Foundation
import SwiftUI

// MARK: - PositionPicker

struct PositionPicker: View {
    var body: some View {
        HStack {
            if isInputMode {
                content.onChange(of: inputPosition) { onChange(inputPosition) }
            } else {
                Menu {
                    Button { startInput() } label: { Text("Input") }
                } label: {
                    content
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .frame(height: 20)
        .padding(6)
        .background(Color.tertiarySystemBackground)
        .cornerRadius(6)
    }

    init(position: Point2,
         onChange: @escaping (Point2) -> Void = { _ in },
         onDone: @escaping (Point2) -> Void = { _ in }) {
        self.position = position
        self.onChange = onChange
        self.onDone = onDone
    }

    // MARK: private

    private let position: Point2
    private let onChange: (Point2) -> Void
    private let onDone: (Point2) -> Void

    @State private var isInputMode: Bool = false
    @State private var inputX: Double = 0
    @State private var inputY: Double = 0

    private var inputPosition: Point2 { Point2(inputX, inputY) }

    private var content: some View {
        Group {
            if isInputMode {
                Button { endInput() } label: { Image(systemName: "checkmark.circle") }
            }
            Image(systemName: "arrow.right")
            if isInputMode {
                DecimalInput(title: "X", inputNumber: $inputX)
            } else {
                Text(position.x.formatted(decimalFormatStyle()))
            }
            Rectangle().frame(width: 1).background(Color.label)
            Image(systemName: "arrow.down")
            if isInputMode {
                DecimalInput(title: "Y", inputNumber: $inputY)
            } else {
                Text(position.y.formatted(decimalFormatStyle()))
            }
        }
        .font(.callout.monospacedDigit())
    }

    private func startInput() {
        isInputMode = true
        inputX = position.x
        inputY = position.y
    }

    private func endInput() {
        isInputMode = false
        onDone(inputPosition)
    }
}
