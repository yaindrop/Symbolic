import SwiftUI

// MARK: - Properties

extension SymbolPanel {
    struct Properties: View, SelectorHolder {
        class Selector: SelectorBase {
            @Selected({ global.activeSymbol.focusedSymbol }) var symbol
            @Selected({ global.activeSymbol.focusedSymbolItem?.symbol }) var symbolItem
        }

        @SelectorWrapper var selector

        var body: some View {
            setupSelector {
                content
            }
        }
    }
}

// MARK: private

private extension SymbolPanel.Properties {
    @ViewBuilder var content: some View {
        if let symbol = selector.symbol, let symbolItem = selector.symbolItem {
            PanelSection(name: "Properties") {
                ContextualRow(label: "ID") {
                    Text(symbol.id.description)
                }
                ContextualDivider()
                ContextualRow(label: "Name") {
                    Text("Unnamed")
                }
                ContextualDivider()
                ContextualRow(label: "Items") {
                    Text("\(symbolItem.members.count)")
                }
                ContextualDivider()
                ContextualRow {
                    Button("Zoom In", systemImage: "arrow.up.left.and.arrow.down.right.square") {
                        global.viewportUpdater.zoomTo(worldRect: symbol.boundingRect)
                    }
                    .contextualFont()
                    Spacer()
                }
            }
        }
    }
}
