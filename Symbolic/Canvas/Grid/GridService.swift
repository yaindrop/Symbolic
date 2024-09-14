import SwiftUI

// MARK: - GridService

struct GridService {
    let world: WorldService
    let activeSymbol: ActiveSymbolService
}

extension GridService {
    var grids: [Grid] {
        if let symbol = activeSymbol.focusedSymbol {
            symbol.grids
        } else if let grid = world.grid {
            [grid]
        } else {
            []
        }
    }

    var grid: Grid? {
        if activeSymbol.focusedSymbol != nil {
            let grids = grids,
                gridIndex = activeSymbol.gridIndex
            guard grids.indices.contains(gridIndex) else { return nil }
            return grids[gridIndex]
        } else {
            return world.grid
        }
    }

    func snap(_ point: Point2) -> Point2 {
        grid?.snap(point) ?? point
    }

    func snappedOffset(_ point: Point2, offset: Vector2) -> Vector2 {
        grid?.snappedOffset(point, offset: offset) ?? offset
    }

    func snapped(_ point: Point2) -> Grid? {
        guard let symbol = activeSymbol.editingSymbol else { return nil }
        return symbol.grids.first { $0.snapped(point) }
    }
}

// MARK: - GridRoot

struct GridRoot: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        override var configs: SelectorConfigs { .syncNotify }
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

private extension GridRoot {
    @ViewBuilder var content: some View {
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
