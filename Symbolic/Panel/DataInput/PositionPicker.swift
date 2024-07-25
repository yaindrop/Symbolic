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
}

// MARK: private

private extension PositionPicker {
    var content: some View {
        HStack(spacing: 0) {
            Image(systemName: "arrow.up.right.square")
                .padding(.leading, 6)
            buttonX
            Divider()
                .padding(.vertical, 6)
            buttonY
        }
        .font(.footnote.monospacedDigit())
        .frame(height: 32)
        .background(Color.tertiarySystemBackground)
        .clipRounded(radius: 6)
        .portal(isPresented: $showNumpadX, configs: portalConfigs) { numpadX }
        .portal(isPresented: $showNumpadY, configs: portalConfigs) { numpadY }
    }

    var portalConfigs: PortalConfigs { .init(isModal: true, align: .topInnerTrailing, gap: .init(squared: 6)) }

    var buttonX: some View {
        Button {
            showNumpadX.toggle()
        } label: {
            Text(position.x.decimalFormatted())
                .padding(.horizontal, 6)
                .frame(maxHeight: .infinity)
        }
        .tint(.label)
        .opacity(showNumpadX ? 0.5 : 1)
    }

    var buttonY: some View {
        Button {
            showNumpadY.toggle()
        } label: {
            Text(position.y.decimalFormatted())
                .padding(.horizontal, 6)
                .frame(maxHeight: .infinity)
        }
        .tint(.label)
        .opacity(showNumpadY ? 0.5 : 1)
    }

    var numpadX: some View {
        NumpadPortal(initialValue: position.x, configs: .init(label: "x")) {
            onChange?(position.with(x: $0))
        } onDone: {
            onDone?(position.with(x: $0))
        }
    }

    var numpadY: some View {
        NumpadPortal(initialValue: position.y, configs: .init(label: "y")) {
            onChange?(position.with(y: $0))
        } onDone: {
            onDone?(position.with(y: $0))
        }
    }
}
