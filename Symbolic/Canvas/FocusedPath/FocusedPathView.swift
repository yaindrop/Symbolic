import SwiftUI

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
            let nodeIds = path.nodeIds
            ZStack {
                Stroke(pathId: path.id)
//                ForEach(nodeIds) { SegmentHandle(pathId: path.id, fromNodeId: $0) }
//                ForEach(nodeIds) { NodeHandle(env: selector, pathId: path.id, nodeId: $0) }
                NodeHandles()
//                ForEach(nodeIds) { FocusedSegmentHandle(env: selector, pathId: path.id, fromNodeId: $0) }
//                ForEach(nodeIds) { BezierHandle(env: selector, pathId: path.id, nodeId: $0) }
            }
            if selector.selectingNodes {
                SelectionBounds()
                    .allowsHitTesting(false)
            }
        }
    }
}
