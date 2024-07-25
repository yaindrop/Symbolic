import SwiftUI

// MARK: - PositionPicker

struct PositionPicker: View {
    let position: Point2
    var onChange: ((Point2) -> Void)?
    var onDone: ((Point2) -> Void)?

    var body: some View {
        content
    }

    @State private var showNumpadX: Bool = false
    @State private var showNumpadY: Bool = false

    private var content: some View {
        HStack(spacing: 0) {
            Image(systemName: "arrow.up.right.square")
                .padding(.leading, 6)

            Button {
                showNumpadX.toggle()
            } label: {
                Text(position.x.decimalFormatted())
                    .padding(.horizontal, 6)
                    .frame(maxHeight: .infinity)
            }
            .tint(.label)

            Divider()
                .padding(.vertical, 6)

            Button {
                showNumpadY.toggle()
            } label: {
                Text(position.y.decimalFormatted())
                    .padding(.horizontal, 6)
                    .frame(maxHeight: .infinity)
            }
            .tint(.label)
        }
        .font(.footnote.monospacedDigit())
        .frame(height: 32)
        .background(Color.tertiarySystemBackground)
        .clipRounded(radius: 6)
        .portal(isPresented: $showNumpadX, isModal: true, align: .topInnerTrailing) {
            NumpadPortal(initialValue: position.x, configs: .init(label: "x")) {
                onChange?(position.with(x: $0))
            } onDone: {
                onDone?(position.with(x: $0))
            }
        }
        .portal(isPresented: $showNumpadY, isModal: true, align: .topInnerTrailing) {
            NumpadPortal(initialValue: position.y, configs: .init(label: "y")) {
                onChange?(position.with(y: $0))
            } onDone: {
                onDone?(position.with(y: $0))
            }
        }
    }
}
