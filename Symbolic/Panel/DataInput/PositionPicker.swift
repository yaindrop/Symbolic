import SwiftUI

// MARK: - PositionPicker

struct PositionPicker: View {
    var body: some View {
        content
//        .frame(height: 20)
//        .padding(6)
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
                .padding(.leading, 6)

            Button {
                isInputMode.toggle()
            } label: {
                Text(position.x.decimalFormatted())
                    .padding(.horizontal, 6)
                    .frame(maxHeight: .infinity)
            }
            .tint(.label)
            .overlay {
                if isInputMode {
                    PortalReference(align: .topLeading) {
                        Numpad(initialValue: position.x) {
                            inputX = $0
                            onChange(inputPosition)
                        } onDone: {
                            inputX = $0
                        }
                    }
                }
            }

            Rectangle().frame(width: 1).background(Color.label)

            Button {
                isInputMode.toggle()
            } label: {
                Text(position.y.decimalFormatted())
                    .padding(.horizontal, 6)
                    .frame(maxHeight: .infinity)
            }
            .tint(.label)
        }
        .font(.footnote.monospacedDigit())
        .frame(height: 32)
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
