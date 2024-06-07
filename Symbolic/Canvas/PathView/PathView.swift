import Foundation
import SwiftUI

private let subtracer = tracer.tagged("PathView")

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

struct PathView: View, SelectorHolder {
    class Selector: SelectorBase {
        @Tracked({ global.viewport.toView }) var toView
    }

    @StateObject var selector = Selector()

    let path: Path
    let property: PathProperty
    let focusedPart: PathFocusedPart?

    var body: some View { subtracer.range("body") {
        setupSelector {
            ZStack {
                Stroke(path: path, toView: selector.toView)
                handles(path: path)
            }
        }
    }}

    // MARK: private

    @ViewBuilder private func handles(path: Path) -> some View {
        let nodes = path.nodes
        let nodeData = nodes.compactMap { n -> (nodeId: UUID, positionInView: Point2)? in
            (nodeId: n.id, positionInView: n.position.applying(selector.toView))
        }
        let segmentData = nodes.compactMap { n -> (fromId: UUID, toId: UUID, segmentInView: PathSegment)? in
            guard let s = path.segment(from: n.id) else { return nil }
            guard let toId = path.node(after: n.id)?.id else { return nil }
            return (fromId: n.id, toId: toId, segmentInView: s.applying(selector.toView))
        }

        ForEach(segmentData, id: \.fromId) { fromId, _, segment in EdgeHandle(property: property, focusedPart: focusedPart, fromId: fromId, segment: segment) }
        ForEach(nodeData, id: \.nodeId) { id, _ in NodeHandle(pathId: path.id, nodeId: id) }
        ForEach(segmentData, id: \.fromId) { fromId, _, segment in FocusedEdgeHandle(property: property, focusedPart: focusedPart, fromId: fromId, segment: segment) }
        ForEach(segmentData, id: \.fromId) { fromId, toId, segment in BezierHandle(property: property, focusedPart: focusedPart, fromId: fromId, toId: toId, segment: segment) }
    }
}

// MARK: - Stroke

extension PathView {
    struct Stroke: View {
        let path: Path
        let toView: CGAffineTransform

        var body: some View { subtracer.range("Stroke") {
            SUPath { path.append(to: &$0) }
                .stroke(Color(UIColor.label), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
                .allowsHitTesting(false)
                .id(path.id)
                .transformEffect(toView)
        }}
    }
}
