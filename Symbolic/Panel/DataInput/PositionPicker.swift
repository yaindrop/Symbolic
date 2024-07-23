import SwiftUI

// MARK: - PositionPicker

struct PositionPicker: View {
    var body: some View {
        HStack {
//            if isInputMode {
//                content.onChange(of: inputPosition) { onChange(inputPosition) }
//            } else {
//                Menu {
            Button {
                isInputMode.toggle()
            } label: { content }
                .tint(.label)

//                } label: {
//                    content
//                }
//                .tint(.label)
//            }
        }
        .overlay {
            if isInputMode {
                PortalReference(align: .topLeading) {
                    Numpad()
                }
            }
        }
        .frame(height: 20)
        .padding(6)
        .background(Color.tertiarySystemBackground)
        .clipRounded(radius: 6)
    }

    init(position: Point2,
         onChange: @escaping (Point2) -> Void = { _ in },
         onDone: @escaping (Point2) -> Void = { _ in })
    {
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
        HStack(spacing: 0) {
            Image(systemName: "arrow.up.right.square")
//            if isInputMode {
//                Button { endInput() } label: { Image(systemName: "checkmark.circle") }
//            }
//            if isInputMode {
//                DecimalInput(title: "X", inputNumber: $inputX)
//            } else {
            Text(position.x.decimalFormatted())
//            }
            Rectangle().frame(width: 1).background(Color.label).padding(.horizontal, 4)
//            if isInputMode {
//                DecimalInput(title: "Y", inputNumber: $inputY)
//            } else {
            Text(position.y.decimalFormatted())
//            }
        }
        .font(.footnote.monospacedDigit())
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
