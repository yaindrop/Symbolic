import SwiftUI

// MARK: - Background

struct Background: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        override var configs: SelectorConfigs { .syncNotify }
        @Selected({ global.viewport.sizedInfo }) var viewport
        @Selected(configs: .init(animation: .fast), { global.activeSymbol.activeGrid }) var grid
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
                        GridView(grid: .init(kind: .cartesian(kind)), viewport: viewport, color: grid.tintColor, type: .background)
                    }
                case let .isometric(kind):
                    AnimatableReader(kind) { kind in
                        GridView(grid: .init(kind: .isometric(kind)), viewport: viewport, color: grid.tintColor, type: .background)
                    }
                default: EmptyView()
                }
            }
        }
    }
}
