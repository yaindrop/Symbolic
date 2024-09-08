import SwiftUI

// MARK: - Background

struct Background: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        override var configs: SelectorConfigs { .syncNotify }
        @Selected({ global.activeSymbol.grid }, .animation(.fast)) var grid
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
            AnimatableReader(selector.viewport) { viewport in
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
}
