import SwiftUI

// MARK: - Background

struct Background: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        override var configs: SelectorConfigs { .syncNotify }
        @Selected({ global.activeSymbol.grid }, .animation(.fast)) var grid
        @Selected({ global.activeSymbol.editingSymbolId }) var editingSymbolId
        @Selected({ global.viewport.sizedInfo }) var viewport
    }

    @SelectorWrapper var selector

    var body: some View { trace {
        setupSelector {
            content
        }
    } }
}

// MARK: private

private extension Background {
    @ViewBuilder var content: some View {
        if let grid = selector.grid {
            AnimatableReader(selector.viewport) {
                Group {
                    if selector.editingSymbolId != nil {
                        SymbolGrid()
                    } else {
                        WorldGrid()
                    }
                }
                .environment(\.sizedViewport, $0)
            }
        }
    }
}
