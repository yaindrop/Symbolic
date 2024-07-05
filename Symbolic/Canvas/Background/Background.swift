import SwiftUI

// MARK: - Background

struct Background: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        override var configs: SelectorConfigs { .init(syncNotify: true) }
        @Selected({ global.viewport.sizedInfo }) var viewport
        @Selected({ global.grid.grid }) var grid
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
        AnimatableReader(selector.viewport) {
            if case let .cartesian(cartesian) = selector.grid {
                CartesianGridView(grid: cartesian, viewport: $0, color: .gray, type: .background)
            }
        }
    }
}
