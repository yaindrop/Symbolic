import SwiftUI

let debugActiveSymbol: Bool = true

// MARK: - ActiveSymbolView

struct ActiveSymbolView: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        @Selected(configs: .syncNotify, { global.viewport.sizedInfo }) var viewport
        @Selected({ global.activeSymbol.activeSymbolIds }) var activeSymbolIds
        @Selected({ global.activeSymbol.focusedSymbolId }) var focusedSymbolId
    }

    @SelectorWrapper var selector

    var body: some View { trace {
        setupSelector {
            content
        }
    } }
}

private extension ActiveSymbolView {
    @ViewBuilder var content: some View {
        AnimatableReader(selector.viewport) {
            ZStack {
                Grid()
                ForEach(Array(selector.activeSymbolIds)) {
                    Bounds(symbolId: $0)
                }
                ResizeHandle()
                SelectionBounds()
            }
            .environment(\.sizedViewport, $0)
        }
    }
}
