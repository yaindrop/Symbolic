import Foundation
import SwiftUI

// MARK: - PathViewModel

class PathViewModel: ObservableObject {
    class NodeGestureContext {
        var longPressAddedNodeId: UUID?
    }

    func nodeGesture(nodeId _: UUID, context _: NodeGestureContext) -> MultipleGesture { .init() }

    class EdgeGestureContext {
        var longPressParamT: Scalar?
        var longPressSplitNodeId: UUID?
    }

    func edgeGesture(fromId _: UUID, segment _: PathSegment, context _: EdgeGestureContext) -> MultipleGesture { .init() }
    func focusedEdgeGesture(fromId _: UUID) -> MultipleGesture { .init() }

    func bezierGesture(fromId _: UUID, isControl0 _: Bool) -> MultipleGesture { .init() }
}

// MARK: - PathView

struct PathView: View, TracedView {
    let path: Path
    let property: PathProperty
    let focusedPart: PathFocusedPart?

    var body: some View { trace {
        ZStack {
            Stroke(path: path)
            handles(path: path)
        }
    } }

    // MARK: private

    @ViewBuilder private func handles(path: Path) -> some View {
        let nodes = path.nodes
        let segmentsNodes = nodes.filter { path.segment(from: $0.id) != nil }
        ForEach(segmentsNodes) { EdgeHandle(pathId: path.id, fromNodeId: $0.id) }
        ForEach(nodes) { NodeHandle(pathId: path.id, nodeId: $0.id) }
        ForEach(segmentsNodes) { FocusedEdgeHandle(pathId: path.id, fromNodeId: $0.id) }
        ForEach(segmentsNodes) { BezierHandle(pathId: path.id, fromNodeId: $0.id) }
    }
}

// MARK: - Stroke

extension PathView {
    struct Stroke: View, TracedView, SelectorHolder {
        class Selector: SelectorBase {
            override var syncUpdate: Bool { true }

            @Selected({ global.viewport.toView }) var toView
        }

        @SelectorWrapper var selector

        let path: Path

        var body: some View { trace {
            setupSelector {
                content
            }
        } }

        private var content: some View {
            SUPath { path.append(to: &$0) }
                .stroke(Color(UIColor.label), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
                .allowsHitTesting(false)
                .id(path.id)
                .transformEffect(selector.toView)
        }
    }
}
