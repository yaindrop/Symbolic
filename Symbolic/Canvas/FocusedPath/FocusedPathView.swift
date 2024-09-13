import SwiftUI

let debugFocusedPath: Bool = false

// MARK: - FocusedPathView

struct FocusedPathView: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        @Selected({ global.focusedPath.selectingNodes }) var selectingNodes
        @Selected({ global.focusedPath.locked }) var locked
        @Selected({ global.activeSymbol.symbolToWorld }) var symbolToWorld
        @Selected({ global.activeItem.focusedPathId != nil }) var active
        @Selected({ global.viewport.sizedInfo }, .syncNotify) var viewport
    }

    @SelectorWrapper var selector

    var body: some View { trace {
        setupSelector {
            content
        }
    } }
}

// MARK: private

private extension FocusedPathView {
    @ViewBuilder var content: some View {
        if selector.active {
            AnimatableReader(selector.viewport) {
                let transform = selector.symbolToWorld.concatenating($0.worldToView)
                ZStack {
                    Stroke()
                    NodeHandles()
                    SegmentHandles()
                    BezierHandles()
                    if selector.selectingNodes {
                        SelectionBounds()
                            .allowsHitTesting(false)
                    }
                }
                .opacity(selector.locked ? 0.5 : 1)
                .allowsHitTesting(!selector.locked)
                .environment(\.transformToView, transform)
            }
        }
    }
}
