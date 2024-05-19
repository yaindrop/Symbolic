import Foundation
import SwiftUI

// MARK: - PathView

class PathViewModel: ObservableObject {
    class EdgeGestureContext {
        var longPressParamT: Scalar?
        var longPressSplitNodeId: UUID?
    }

    func boundsGesture() -> MultipleGestureModel<Void>? { nil }
    func nodeGesture(nodeId: UUID) -> MultipleGestureModel<Point2>? { nil }
    func edgeGesture(fromId: UUID) -> (MultipleGestureModel<PathSegment>, EdgeGestureContext)? { nil }
    func focusedEdgeGesture(fromId: UUID) -> MultipleGestureModel<Point2>? { nil }
    func bezierGesture(fromId: UUID, updater: @escaping (Point2) -> PathEdge.Bezier) -> MultipleGestureModel<Void>? { nil }
    func arcGesture(fromId: UUID, updater: @escaping (Scalar) -> PathEdge.Arc) -> MultipleGestureModel<Point2>? { nil }
}

// MARK: - PathView

struct PathView: View {
    let path: Path
    let focusedPart: PathFocusedPart?

    var body: some View { tracer.range("PathView") { build {
        ZStack {
            PathBody(path: path, toView: toView)
            PathHandle(path: path, toView: toView)
            handles(path: path)
        }
    }}}

    // MARK: private

    @Selected private var toView = store.viewport.toView

    @ViewBuilder private func handles(path: Path) -> some View {
        let nodes = path.nodes
        let idAndNodePositionInView = nodes.compactMap { n -> (id: UUID, position: Point2)? in
            (id: n.id, position: n.position.applying(toView))
        }
        let idAndSegmentInView = nodes.compactMap { n -> (fromId: UUID, toId: UUID, segment: PathSegment)? in
            guard let s = path.segment(from: n.id) else { return nil }
            guard let toId = path.node(after: n.id)?.id else { return nil }
            return (fromId: n.id, toId: toId, segment: s.applying(toView))
        }

        ForEach(idAndSegmentInView, id: \.fromId) { fromId, _, segment in EdgeHandle(fromId: fromId, segment: segment, focusedPart: focusedPart) }
        ForEach(idAndNodePositionInView, id: \.id) { id, position in NodeHandle(nodeId: id, position: position, focusedPart: focusedPart) }
        ForEach(idAndSegmentInView, id: \.fromId) { fromId, _, segment in FocusedEdgeHandle(fromId: fromId, segment: segment, focusedPart: focusedPart) }
        ForEach(idAndSegmentInView, id: \.fromId) { fromId, toId, segment in EdgeKindHandle(fromId: fromId, toId: toId, segment: segment, focusedPart: focusedPart) }
    }
}

extension PathView {
    // MARK: - PathBody

    struct PathBody: View {
        let path: Path
        let toView: CGAffineTransform

        var body: some View { tracer.range("PathView PathBody") {
            SUPath { path.append(to: &$0) }
                .stroke(Color(UIColor.label), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
                .allowsHitTesting(false)
                .id(path.id)
                .transformEffect(toView)
        }}
    }

    // MARK: - PathHandle

    struct PathHandle: View {
        @EnvironmentObject var viewModel: PathViewModel

        let path: Path
        let toView: CGAffineTransform

        var body: some View { tracer.range("PathView PathHandle") {
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
