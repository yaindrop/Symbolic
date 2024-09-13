import SwiftUI

// MARK: - SymbolPanel

struct SymbolPanel: View, TracedView, SelectorHolder {
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

extension SymbolPanel {
    @ViewBuilder private var content: some View {
        if selector.focusedSymbolId != nil {
            Properties()
            Selection()
            Items()
        } else {
            PanelPlaceholder(text: "No symbol is focused")
        }
    }
}
