import SwiftUI

// MARK: - ActiveSymbolView

struct ActiveSymbolView: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        @Selected({ global.activeSymbol.activeSymbolIds }) var activeSymbolIds
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
        ForEach(Array(selector.activeSymbolIds)) {
            Bounds(symbolId: $0)
        }
//        SelectionBounds()
    }
}