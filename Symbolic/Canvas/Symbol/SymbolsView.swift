import SwiftUI

// MARK: - SymbolsView

struct SymbolsView: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        override var configs: SelectorConfigs { .init(syncNotify: true) }
        @Selected({ global.viewport.sizedInfo }) var viewport
        @Selected({ global.symbol.symbolIds }) var symbolIds
        @Selected({ global.symbol.symbolMap }) var symbolMap
        @Selected({ global.item.symbolItemMap }) var symbolItemMap
        @Selected({ global.path.pathMap }) var pathMap
        @Selected({ global.activeSymbol.unfocusedSymbolIds }) var unfocusedSymbolIds
    }

    @SelectorWrapper var selector

    var body: some View { trace {
        setupSelector {
            content
        }
    } }
}

// MARK: private

private extension SymbolsView {
    @ViewBuilder var content: some View {
        AnimatableReader(selector.viewport) {
            ForEach(selector.unfocusedSymbolIds) { symbolId in
                symbolView(symbolId: symbolId)
            }
            .transformEffect($0.worldToView)
        }
//        .blur(radius: 1)
    }

    @ViewBuilder func symbolView(symbolId: UUID) -> some View {
        if let symbol = selector.symbolMap.get(symbolId) {
            symbolPaths(symbolId: symbolId)
                .background {
                    Rectangle()
                        .fill(Color.label.opacity(0.05))
                        .framePosition(rect: symbol.rect)
                }
        }
    }

    @ViewBuilder func symbolPaths(symbolId: UUID) -> some View {
        ForEach(selector.symbolItemMap.get(symbolId) ?? []) { item in
            SUPath { path in selector.pathMap.get(item.id)?.append(to: &path) }
                .stroke(Color(UIColor.label), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
        }
    }
}
