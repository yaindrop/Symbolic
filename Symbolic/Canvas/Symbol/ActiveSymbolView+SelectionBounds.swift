import SwiftUI

// MARK: - SelectionBounds

extension ActiveSymbolView {
    struct SelectionBounds: View, TracedView, SelectorHolder {
        @Environment(\.transformToView) var transformToView

        class Selector: SelectorBase {
            override var configs: SelectorConfigs { .init(syncNotify: true) }
            @Selected({ global.activeSymbol.selectionBounds }) var bounds
            @Selected({ global.activeSymbol.selectionOutset }) var outset
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

extension ActiveSymbolView.SelectionBounds {
    var lineWidth: Scalar { 2 }
    var dashSize: Scalar { 8 }

    @ViewBuilder var content: some View {
        if let bounds = selector.bounds {
            let bounds = bounds.applying(transformToView).outset(by: selector.outset)
            RoundedRectangle(cornerRadius: 8)
                .stroke(.blue.opacity(0.5), style: .init(lineWidth: lineWidth, dash: [dashSize], dashPhase: dashPhase))
                .framePosition(rect: bounds)
                .animatedValue($dashPhase, from: 0, to: dashSize * 2, .linear(duration: 0.4).repeatForever(autoreverses: false))
        }
    }
}
