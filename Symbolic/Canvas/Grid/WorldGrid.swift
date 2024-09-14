import SwiftUI

// MARK: - WorldGrid

struct WorldGrid: View, TracedView, SelectorHolder {
    @Environment(\.sizedViewport) var viewport

    class Selector: SelectorBase {
        override var configs: SelectorConfigs { .syncNotify }
        @Selected({ global.world.grid }, .animation(.fast)) var grid
    }

    @SelectorWrapper var selector

    var body: some View { trace {
        setupSelector {
            content
        }
    } }
}

// MARK: private

extension WorldGrid {
    @ViewBuilder var content: some View {
        if let grid = selector.grid {
            switch grid.kind {
            case let .cartesian(kind):
                AnimatableReader(kind) { kind in
                    GridLines(grid: .init(kind: .cartesian(kind)), viewport: viewport)
                    GridLabels(grid: .init(kind: .cartesian(kind)), viewport: viewport, hasSafeArea: true)
                }
            case let .isometric(kind):
                AnimatableReader(kind) { kind in
                    GridLines(grid: .init(kind: .isometric(kind)), viewport: viewport)
                    GridLabels(grid: .init(kind: .isometric(kind)), viewport: viewport, hasSafeArea: true)
                }
            default: EmptyView()
            }
        }
    }
}
