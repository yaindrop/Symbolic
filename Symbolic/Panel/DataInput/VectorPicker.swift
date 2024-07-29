import SwiftUI

// MARK: - VectorPicker

struct VectorPicker: View {
    let value: Vector2
    var onChange: ((Vector2) -> Void)?
    var onDone: ((Vector2) -> Void)?

    @State private var showNumpads: Bool = false

    var body: some View {
        content
    }
}

// MARK: private

private extension VectorPicker {
    var content: some View {
        button
            .portal(isPresented: $showNumpads, configs: portalConfigs) { numpads }
    }

    var portalConfigs: PortalConfigs { .init(isModal: true, align: .topInnerTrailing, gap: .init(squared: 6)) }

    var button: some View {
        Button { showNumpads.toggle() } label: { label }
            .tint(.label)
            .opacity(showNumpads ? 0.5 : 1)
    }

    var label: some View {
        HStack(spacing: 0) {
            Text(value.dx.decimalFormatted())
                .padding(.horizontal, 6)
                .frame(maxHeight: .infinity)
            Divider()
                .padding(.vertical, 6)
            Text(value.dy.decimalFormatted())
                .padding(.horizontal, 6)
                .frame(maxHeight: .infinity)
        }
        .font(.footnote.monospacedDigit())
    }

    var numpads: some View {
        HStack {
            NumpadPortal(initialValue: value.dx, configs: .init(label: "x")) {
                onChange?(value.with(dx: $0))
            } onDone: {
                onDone?(value.with(dx: $0))
            }
            NumpadPortal(initialValue: value.dy, configs: .init(label: "y")) {
                onChange?(value.with(dy: $0))
            } onDone: {
                onDone?(value.with(dy: $0))
            }
        }
    }
}
