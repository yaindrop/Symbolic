import Foundation
import SwiftUI

fileprivate let subtracer = tracer.tagged("PathView")

// MARK: - PathViewModel

class PathViewModel: ObservableObject {
    func boundsGesture() -> MultipleGestureModel<Void>? { nil }

    class NodeGestureContext {
        var longPressAddedNodeId: UUID?
    }

    func nodeGesture(nodeId: UUID) -> (MultipleGestureModel<Point2>, NodeGestureContext)? { nil }

    class EdgeGestureContext {
        var longPressParamT: Scalar?
        var longPressSplitNodeId: UUID?
    }

    func edgeGesture(fromId: UUID) -> (MultipleGestureModel<PathSegment>, EdgeGestureContext)? { nil }
    func focusedEdgeGesture(fromId: UUID) -> MultipleGestureModel<Point2>? { nil }

    func bezierGesture(fromId: UUID, isControl0: Bool) -> MultipleGestureModel<Void>? { nil }
    func arcGesture(fromId: UUID, updater: @escaping (PathEdge.Arc, Scalar) -> PathEdge.Arc) -> MultipleGestureModel<(PathEdge.Arc, Point2)>? { nil }
}

// MARK: - PathView

struct PathView: View {
    let path: Path
    let focusedPart: PathFocusedPart?

    var body: some View { subtracer.range("body") { build {
        ZStack {
            BoundsHandle(path: path, toView: toView)
            Stroke(path: path, toView: toView)
            handles(path: path)
        }
    }}}

    // MARK: private

    @Selected private var toView = global.viewport.toView

    @ViewBuilder private func handles(path: Path) -> some View {
        let nodes = path.nodes
        let nodeData = nodes.compactMap { n -> (nodeId: UUID, positionInView: Point2)? in
            (nodeId: n.id, positionInView: n.position.applying(toView))
        }
        let segmentData = nodes.compactMap { n -> (fromId: UUID, toId: UUID, segmentInView: PathSegment)? in
            guard let s = path.segment(from: n.id) else { return nil }
            guard let toId = path.node(after: n.id)?.id else { return nil }
            return (fromId: n.id, toId: toId, segmentInView: s.applying(toView))
        }

        ForEach(segmentData, id: \.fromId) { fromId, _, segment in EdgeHandle(fromId: fromId, segment: segment, focusedPart: focusedPart) }
        ForEach(nodeData, id: \.nodeId) { id, position in NodeHandle(nodeId: id, position: position, focusedPart: focusedPart) }
        ForEach(segmentData, id: \.fromId) { fromId, _, segment in FocusedEdgeHandle(fromId: fromId, segment: segment, focusedPart: focusedPart) }
        ForEach(segmentData, id: \.fromId) { fromId, toId, segment in EdgeKindHandle(fromId: fromId, toId: toId, segment: segment, focusedPart: focusedPart) }
    }
}

extension PathView {
    // MARK: - Stroke

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

    // MARK: - BoundsHandle

    struct BoundsHandle: View {
        @EnvironmentObject var viewModel: PathViewModel

        let path: Path
        let toView: CGAffineTransform

        var body: some View { subtracer.range("BoundsHandle") {
            rect
        }}

        // MARK: private

        private var boundingRectInView: CGRect { path.boundingRect.applying(toView) }

        private static let lineWidth: Scalar = 1
        private static let circleSize: Scalar = 16
        private static let touchablePadding: Scalar = 16

        @State private var gesture: MultipleGestureModel<Void>?

        @ViewBuilder private var rect: some View {
            Rectangle()
                .stroke(.blue, style: StrokeStyle(lineWidth: Self.lineWidth))
                .fill(.blue.opacity(0.2))
                .frame(width: boundingRectInView.width, height: boundingRectInView.height)
                .position(boundingRectInView.center)
                .if(gesture) {
                    $0.multipleGesture($1, ())
                }
                .onAppear {
                    gesture = viewModel.boundsGesture()
                }
        }
    }
}
