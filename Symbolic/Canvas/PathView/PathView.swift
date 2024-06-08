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

    var body: some View { trace {
        content
    } }

    // MARK: private

    @ViewBuilder private var content: some View {
        let nodeIds = path.nodes.map { $0.id }
        let segmentIds = path.nodes.filter { path.segment(from: $0.id) != nil }.map { $0.id }
        ZStack {
            Stroke(pathId: path.id)
            ForEach(segmentIds) { EdgeHandle(pathId: path.id, fromNodeId: $0) }
            ForEach(nodeIds) { NodeHandle(pathId: path.id, nodeId: $0) }
            ForEach(segmentIds) { FocusedEdgeHandle(pathId: path.id, fromNodeId: $0) }
            ForEach(segmentIds) { BezierHandle(pathId: path.id, fromNodeId: $0) }
        }
    }
}

// MARK: - Stroke

extension PathView {
    struct Stroke: View, TracedView, ComputedSelectorHolder {
        struct SelectorProps: Equatable { let pathId: UUID }
        class Selector: SelectorBase {
            override var syncUpdate: Bool { true }

            @Selected({ global.path.path(id: $0.pathId) }) var path
            @Selected({ global.viewport.toView }) var toView
        }

        @SelectorWrapper var selector

        let pathId: UUID

        var body: some View { trace {
            setupSelector(.init(pathId: pathId)) {
                content
            }
        } }

        @ViewBuilder private var content: some View {
            if let path = selector.path {
                SUPath { path.append(to: &$0) }
                    .stroke(Color(UIColor.label), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
                    .allowsHitTesting(false)
                    .id(path.id)
                    .transformEffect(selector.toView)
            }
        }
    }
}
