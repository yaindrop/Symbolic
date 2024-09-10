import SwiftUI

let debugActiveSymbol: Bool = true

// MARK: - ActiveSymbolView

struct ActiveSymbolView: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        @Selected({ global.activeSymbol.activeSymbolIds }) var activeSymbolIds
        @Selected({ global.activeSymbol.focusedSymbolId }) var focusedSymbolId
        @Selected({ global.viewport.sizedInfo }, .syncNotify) var viewport
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
