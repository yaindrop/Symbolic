import SwiftUI

let debugFocusedPath: Bool = true

// MARK: - FocusedPathView

struct FocusedPathView: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        @Selected({ global.activeItem.focusedPath }) var path
        @Selected({ global.focusedPath.selectingNodes }) var selectingNodes
        @Selected(configs: .init(syncNotify: true), { global.viewport.sizedInfo }) var viewport
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
        if selector.path != nil {
            ZStack {
                Stroke()
                NodeHandles()
                SegmentHandles()
                BezierHandles()
            }
            if selector.selectingNodes {
                SelectionBounds()
                    .allowsHitTesting(false)
            }
        }
    }
}
