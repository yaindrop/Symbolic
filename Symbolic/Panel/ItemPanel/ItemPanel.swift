import SwiftUI

// MARK: - ItemPanel

struct ItemPanel: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        @Selected({ global.activeSymbol.focusedSymbolId }) var focusedSymbolId
    }

    @SelectorWrapper var selector

    var body: some View { trace {
        setupSelector {
            content
        }
    } }
}

// MARK: private

extension ItemPanel {
    @ViewBuilder private var content: some View {
        if selector.focusedSymbolId != nil {
            Selection()
            Items()
        } else {
            PanelPlaceholder(text: "No symbol is focused")
        }
    }
}
