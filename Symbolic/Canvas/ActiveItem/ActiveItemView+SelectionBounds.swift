import SwiftUI

// MARK: - SelectionBounds

extension ActiveItemView {
    struct SelectionBounds: View, TracedView, SelectorHolder {
        class Selector: SelectorBase {
            override var configs: SelectorConfigs { .init(syncNotify: true) }
            @Selected({ global.viewport.sizedInfo }) var viewport
            @Selected({ global.activeItem.selectionBounds }) var bounds
            @Selected({ global.activeItem.selectionOutset }) var outset
        }

        @SelectorWrapper var selector

        @State private var dashPhase: Scalar = 0

        var body: some View { trace {
            setupSelector {
                content
            }
        } }
    }
}

// MARK: private

extension ActiveItemView.SelectionBounds {
    var lineWidth: Scalar { 2 }
    var dashSize: Scalar { 8 }

    @ViewBuilder var content: some View {
        if let bounds = selector.bounds {
            AnimatableReader(selector.viewport) {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.blue.opacity(0.5), style: .init(lineWidth: lineWidth, dash: [dashSize], dashPhase: dashPhase))
                    .framePosition(rect: bounds.applying($0.worldToView).outset(by: selector.outset))
                    .animatedValue($dashPhase, from: 0, to: dashSize * 2, .linear(duration: 0.4).repeatForever(autoreverses: false))
            }
        }
    }
}
