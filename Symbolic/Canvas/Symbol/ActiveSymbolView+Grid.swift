import SwiftUI

// MARK: - Grid

extension ActiveSymbolView {
    struct Grid: View, TracedView, SelectorHolder {
        @Environment(\.sizedViewport) var viewport

        class Selector: SelectorBase {
            override var configs: SelectorConfigs { .syncNotify }
            @Selected({ global.activeSymbol.activeGrid }) var activeGrid
            @Selected({ global.activeSymbol.worldToSymbol }) var worldToSymbol
        }

        @SelectorWrapper var selector

        var body: some View { trace {
            setupSelector {
                content
            }
        } }
    }
}

// MARK: private

extension ActiveSymbolView.Grid {
    @ViewBuilder var content: some View {
        if let grid = selector.activeGrid {
            let origin = viewport.origin.applying(selector.worldToSymbol),
                gridViewport = SizedViewportInfo(size: viewport.size, info: .init(origin: origin, scale: viewport.scale))
            GridView(grid: grid, viewport: gridViewport, color: grid.tintColor, type: .background)
        }
    }
}
