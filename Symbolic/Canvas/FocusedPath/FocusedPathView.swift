import SwiftUI

// MARK: - FocusedPathView

struct FocusedPathView: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        @Selected({ global.activeItem.focusedPath }) var path
        @Selected({ global.focusedPath.selectingNodes }) var selectingNodes
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
                ForEach(nodeIds) { SegmentHandle(pathId: path.id, fromNodeId: $0) }
                ForEach(nodeIds) { NodeHandle(pathId: path.id, nodeId: $0) }
                ForEach(nodeIds) { FocusedSegmentHandle(pathId: path.id, fromNodeId: $0) }
                ForEach(nodeIds) { BezierHandle(pathId: path.id, nodeId: $0) }
            }
            if selector.selectingNodes {
                SelectionBounds()
                    .allowsHitTesting(false)
            }
        }
    }
}
