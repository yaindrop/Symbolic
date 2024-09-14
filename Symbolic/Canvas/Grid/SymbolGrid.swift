import SwiftUI

// MARK: - SymbolGrid

struct SymbolGrid: View, TracedView, SelectorHolder {
    @Environment(\.sizedViewport) var viewport

    class Selector: SelectorBase {
        override var configs: SelectorConfigs { .syncNotify }
        @Selected({ global.activeSymbol.editingSymbol }) var editingSymbol
        @Selected({ global.grid.grid }) var grid
        @Selected({ global.activeSymbol.worldToSymbol }) var worldToSymbol
    }

    @SelectorWrapper var selector

    var body: some View { trace {
        setupSelector {
            content
        }
    } }
}

// MARK: private

extension SymbolGrid {
    @ViewBuilder var content: some View {
        if let editingSymbol = selector.editingSymbol, let grid = selector.grid {
            let origin = viewport.origin.applying(selector.worldToSymbol),
                gridViewport = SizedViewportInfo(size: viewport.size, info: .init(origin: origin, scale: viewport.scale)),
                bounds = editingSymbol.boundingRect.applying(viewport.worldToView).outset(by: ActiveSymbolService.editingBoundsOutset)
            GridLines(grid: grid, viewport: gridViewport)
                .mask { mask(bounds: bounds) }
            GridLabels(grid: grid, viewport: gridViewport, hasSafeArea: true)
        }
    }

    @ViewBuilder func mask(bounds: CGRect) -> some View {
        ZStack {
            Rectangle()
                .opacity(0.2)
            RoundedRectangle(cornerRadius: ActiveSymbolService.editingBoundsRadius)
                .path(in: bounds)
        }
    }
}
