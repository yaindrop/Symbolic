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
            let nodeIds = path.nodes.map { $0.id }
            let segmentIds = path.nodes.filter { path.segment(from: $0.id) != nil }.map { $0.id }
            ZStack {
                Stroke(pathId: path.id)
                ForEach(segmentIds) { EdgeHandle(pathId: path.id, fromNodeId: $0) }
                ForEach(nodeIds) { NodeHandle(pathId: path.id, nodeId: $0) }
                ForEach(segmentIds) { FocusedEdgeHandle(pathId: path.id, fromNodeId: $0) }
                ForEach(segmentIds) { BezierHandle(pathId: path.id, fromNodeId: $0) }
            }
            if selector.selectingNodes {
                SelectionBounds()
                    .allowsHitTesting(false)
            }
        }
    }
}
