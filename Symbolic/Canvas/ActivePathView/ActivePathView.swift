import Foundation
import SwiftUI

// MARK: - ActivePathView

struct ActivePathView: View {
    var body: some View { tracer.range("ActivePathHandleRoot body") { build {
        if let activePath {
            ZStack {
                PathBody(activePath: activePath, toView: toView)
                PathHandle(activePath: activePath, toView: toView)
                handles(path: activePath)
            }
        }
    }}}

    // MARK: private

    @Selected private var toView = store.viewport.toView
    @Selected private var activePath = service.activePath.pendingActivePath

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
        ForEach(idAndSegmentInView, id: \.fromId) { fromId, _, segment in EdgeHandle(fromId: fromId, segment: segment) }
        ForEach(idAndNodePositionInView, id: \.id) { id, position in NodeHandle(nodeId: id, position: position) }
        ForEach(idAndSegmentInView, id: \.fromId) { fromId, _, segment in FocusedEdgeHandle(fromId: fromId, segment: segment) }
        ForEach(idAndSegmentInView, id: \.fromId) { fromId, toId, segment in EdgeKindHandle(fromId: fromId, toId: toId, segment: segment) }
    }
}

// MARK: - PathBody

extension ActivePathView {
    struct PathBody: View {
        let activePath: Path
        let toView: CGAffineTransform

        var body: some View { tracer.range("ActivePathView PathHandle body") {
            path
        }}

        // MARK: private

        @ViewBuilder private var path: some View { tracer.range("ActivePathView PathBody body") {
            SUPath { path in activePath.append(to: &path) }
                .stroke(Color(UIColor.label), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
                .allowsHitTesting(false)
                .id(activePath.id)
                .transformEffect(toView)
        }}
    }
}

// MARK: - PathHandle

extension ActivePathView {
    struct PathHandle: View {
        let activePath: Path
        let toView: CGAffineTransform

        var body: some View { tracer.range("ActivePathView PathHandle body") {
            rect
        }}

        // MARK: private

        private var boundingRectInView: CGRect { activePath.boundingRect.applying(toView) }

        private static let lineWidth: Scalar = 1
        private static let circleSize: Scalar = 16
        private static let touchablePadding: Scalar = 16

        @State private var dragGesture = MultipleGestureModel<Void>()

        @ViewBuilder private var rect: some View {
            Rectangle()
                .stroke(.blue, style: StrokeStyle(lineWidth: Self.lineWidth))
                .fill(.blue.opacity(0.2))
                .frame(width: boundingRectInView.width, height: boundingRectInView.height)
                .position(boundingRectInView.center)
                .multipleGesture(dragGesture, ()) {
                    func update(pending: Bool = false) -> (DragGesture.Value, Void) -> Void {
                        { v, _ in service.pathUpdaterInView.updateActivePath(moveByOffset: Vector2(v.translation), pending: pending) }
                    }
                    $0.onDrag(update(pending: true))
                    $0.onDragEnd(update())
                }
        }
    }
}
