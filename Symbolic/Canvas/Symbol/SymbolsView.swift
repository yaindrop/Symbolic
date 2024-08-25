import SwiftUI

// MARK: - SymbolsView

struct SymbolsView: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        override var configs: SelectorConfigs { .init(syncNotify: true) }
        @Selected({ global.viewport.sizedInfo }) var viewport
        @Selected({ global.symbol.symbolIds }) var symbolIds
        @Selected({ global.item.symbolItemMap }) var symbolItemMap
        @Selected({ global.path.map }) var pathMap
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
                ForEach(selector.symbolItemMap.value(key: symbolId) ?? []) { item in
                    SUPath { path in selector.pathMap.value(key: item.id)?.append(to: &path) }
                        .stroke(Color(UIColor.label), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
                }
            }
            .transformEffect($0.worldToView)
        }
//        .blur(radius: 1)
    }
}
