import SwiftUI

// MARK: - SelectionBounds

extension ActiveItemView {
    struct SelectionBounds: View, TracedView, SelectorHolder {
        class Selector: SelectorBase {
            override var syncUpdate: Bool { true }
            @Selected({ global.activeItem.selectionBounds }) var bounds
        }

        @SelectorWrapper var selector

        var body: some View { trace {
            setupSelector {
                boundsRect
            }
        } }

        // MARK: private

        @State private var dashPhase: Scalar = 0

        @ViewBuilder private var boundsRect: some View {
            if let bounds = selector.bounds {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.blue.opacity(0.5), style: .init(lineWidth: 2, dash: [8], dashPhase: dashPhase))
                    .framePosition(rect: bounds)
                    .modifier(AnimatedValue(value: $dashPhase, from: 0, to: 16, animation: .linear(duration: 0.4).repeatForever(autoreverses: false)))
            }
        }
    }
}
