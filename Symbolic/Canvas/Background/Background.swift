import SwiftUI

// MARK: - Background

struct Background: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        override var configs: SelectorConfigs { .init(syncNotify: true) }
        @Selected({ global.viewport.sizedInfo }) var viewport
        @Selected(configs: .init(animation: .fast), { global.grid.grid }) var grid
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
        AnimatableReader(selector.viewport) { viewport in
            switch selector.grid.kind {
            case let .cartesian(grid):
                AnimatableReader(grid) { grid in
                    GridView(grid: .init(kind: .cartesian(grid)), viewport: viewport, color: selector.grid.tintColor, type: .background)
                }
            case let .isometric(grid):
                AnimatableReader(grid) { grid in
                    GridView(grid: .init(kind: .isometric(grid)), viewport: viewport, color: selector.grid.tintColor, type: .background)
                }
            default: EmptyView()
            }
        }
    }
}
