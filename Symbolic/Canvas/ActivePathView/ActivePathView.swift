import Foundation
import SwiftUI

// MARK: - ActivePathHandleRoot

struct ActivePathView: View {
    var body: some View { tracer.range("ActivePathHandleRoot body") { build {
        if let activePath {
            let nodes = activePath.nodes
            let idAndNodePositionInView = nodes.compactMap { n -> (id: UUID, position: Point2)? in
                (id: n.id, position: n.position.applying(toView))
            }
            let idAndSegmentInView = nodes.compactMap { n -> (fromId: UUID, toId: UUID, segment: PathSegment)? in
                guard let s = activePath.segment(from: n.id) else { return nil }
                guard let toId = activePath.node(after: n.id)?.id else { return nil }
                return (fromId: n.id, toId: toId, segment: s.applying(toView))
            }
            ZStack {
                pathBody
                ActivePathHandle()
                ForEach(idAndSegmentInView, id: \.fromId) { fromId, _, segment in ActivePathEdgeHandle(fromId: fromId, segment: segment) }
                ForEach(idAndNodePositionInView, id: \.id) { id, position in ActivePathNodeHandle(nodeId: id, position: position) }
                ForEach(idAndSegmentInView, id: \.fromId) { fromId, _, segment in ActivePathFocusedEdgeHandle(fromId: fromId, segment: segment) }
                ForEach(idAndSegmentInView, id: \.fromId) { fromId, toId, segment in ActivePathEdgeKindHandle(fromId: fromId, toId: toId, segment: segment) }
            }
        }
    }}}

    @Selected private var toView = store.viewport.toView
    @Selected private var activePath = service.activePath.pendingActivePath

    @ViewBuilder private var pathBody: some View {
        if let activePath {
            SUPath { path in activePath.append(to: &path) }
                .stroke(Color(UIColor.label), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
                .allowsHitTesting(false)
                .id(activePath.id)
                .transformEffect(toView)
        }
    }
}
