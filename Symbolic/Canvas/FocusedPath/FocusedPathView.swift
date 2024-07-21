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
        if let path = selector.path {
            ZStack {
                Stroke(pathId: path.id)
//                ForEach(nodeIds) { SegmentHandle(pathId: path.id, fromNodeId: $0) }
                NodeHandles()
                BezierHandles()
//                ForEach(nodeIds) { FocusedSegmentHandle(env: selector, pathId: path.id, fromNodeId: $0) }
            }
            if selector.selectingNodes {
                SelectionBounds()
                    .allowsHitTesting(false)
            }
        }
    }
}
