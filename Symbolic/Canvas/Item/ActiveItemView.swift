import SwiftUI

// MARK: - ActiveItemView

struct ActiveItemView: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        @Selected({ global.activeSymbol.symbolToWorld }) var symbolToWorld
        @Selected({ !global.activeItem.activeItems.isEmpty }) var active
        @Selected({ global.activeItem.activePathIds }) var activePathIds
        @Selected({ global.activeItem.activeGroups }) var activeGroups
        @Selected(configs: .syncNotify, { global.viewport.sizedInfo }) var viewport
    }

    @SelectorWrapper var selector

    var body: some View { trace {
        setupSelector {
            content
        }
    } }
}

private extension ActiveItemView {
    @ViewBuilder var content: some View {
        if selector.active {
            AnimatableReader(selector.viewport) {
                let transform = selector.symbolToWorld.concatenating($0.worldToView)
                ZStack {
                    ForEach(selector.activeGroups) {
                        GroupBounds(group: $0)
                    }
                    ForEach(selector.activePathIds) {
                        PathBounds(pathId: $0)
                    }
                    SelectionBounds()
                }
                .environment(\.transformToView, transform)
            }
        }
    }
}
