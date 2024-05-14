import Foundation
import SwiftUI

// MARK: - ActivePathHandleRoot

struct ActivePathHandleRoot: View {
    var body: some View { tracer.range("ActivePathHandleRoot body") {
        if let activePath = activePathInteractor.pendingActivePath {
            ZStack {
                let nodes = activePath.nodes
                let idAndNodePositionInView = nodes.compactMap { n -> (id: UUID, position: Point2)? in
                    (id: n.id, position: n.position.applying(store.viewportModel.toView))
                }
                let idAndSegmentInView = nodes.compactMap { n -> (fromId: UUID, toId: UUID, segment: PathSegment)? in
                    guard let s = activePath.segment(from: n.id) else { return nil }
                    guard let toId = activePath.node(after: n.id)?.id else { return nil }
                    return (fromId: n.id, toId: toId, segment: s.applying(store.viewportModel.toView))
                }
                ActivePathHandle()
                ForEach(idAndSegmentInView, id: \.fromId) { fromId, _, segment in ActivePathEdgeHandle(fromId: fromId, segment: segment) }
                ForEach(idAndNodePositionInView, id: \.id) { id, position in ActivePathNodeHandle(nodeId: id, position: position) }
                ForEach(idAndSegmentInView, id: \.fromId) { fromId, _, segment in ActivePathFocusedEdgeHandle(fromId: fromId, segment: segment) }
                ForEach(idAndSegmentInView, id: \.fromId) { fromId, toId, segment in ActivePathEdgeKindHandle(fromId: fromId, toId: toId, segment: segment) }
            }
        }
    }}
}
