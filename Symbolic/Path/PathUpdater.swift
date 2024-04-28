import Combine
import Foundation
import SwiftUI

// MARK: - PathUpdater

class PathUpdater: ObservableObject {
    let activePathModel: ActivePathModel
    let viewport: Viewport

    // MARK: single update

    func updateActivePath(node id: UUID, position: Point2, pending: Bool = false) {
        guard let activePath else { return }
        let pathEvent = PathEvent(in: activePath.id, updateNode: activePath.node(id: id)!.with(position: position))
        let event = DocumentEvent(kind: .pathEvent(pathEvent))
        (pending ? pendingEventSubject : eventSubject).send(event)
    }

    func updateActivePath(edge fromNodeId: UUID, bezier: PathBezier, pending: Bool = false) {
        guard let activePath else { return }
        let pathEvent = PathEvent(in: activePath.id, updateEdgeFrom: fromNodeId, .Bezier(bezier))
        let event = DocumentEvent(kind: .pathEvent(pathEvent))
        (pending ? pendingEventSubject : eventSubject).send(event)
    }

    func updateActivePath(edge fromNodeId: UUID, arc: PathArc, pending: Bool = false) {
        guard let activePath else { return }
        let pathEvent = PathEvent(in: activePath.id, updateEdgeFrom: fromNodeId, .Arc(arc))
        let event = DocumentEvent(kind: .pathEvent(pathEvent))
        (pending ? pendingEventSubject : eventSubject).send(event)
    }

    func updateActivePath(node id: UUID, positionInView: Point2, pending: Bool = false) {
        updateActivePath(node: id, position: positionInView.applying(viewport.info.viewToWorld), pending: pending)
    }

    func updateActivePath(edge fromNodeId: UUID, bezierInView: PathBezier, pending: Bool = false) {
        updateActivePath(edge: fromNodeId, bezier: bezierInView.applying(viewport.info.viewToWorld), pending: pending)
    }

    func updateActivePath(edge fromNodeId: UUID, arcInView: PathArc, pending: Bool = false) {
        updateActivePath(edge: fromNodeId, arc: arcInView.applying(viewport.info.viewToWorld), pending: pending)
    }

    // MARK: compound update

    func updateActivePath(nodeAndControl id: UUID, delta: Vector2, pending: Bool = false) {
        guard let activePath else { return }
        guard let segment = activePath.segment(id: id) else { return }
        print("delta", delta)
        var compound: [CompoundEventKind] = []
        let pathEvent = PathEvent(in: activePath.id, updateNode: segment.node.with(position: segment.node.position + delta))
        compound.append(.pathEvent(pathEvent))
        if let prevId = segment.prevId, case let .Bezier(bezier) = segment.prevEdge {
            let prevEdge = PathEdge.Bezier(bezier.with(control1: bezier.control1 + delta))
            let pathEvent = PathEvent(in: activePath.id, updateEdgeFrom: prevId, prevEdge)
            compound.append(.pathEvent(pathEvent))
        }
        if case let .Bezier(bezier) = segment.edge {
            let edge = PathEdge.Bezier(bezier.with(control0: bezier.control0 + delta))
            let pathEvent = PathEvent(in: activePath.id, updateEdgeFrom: id, edge)
            compound.append(.pathEvent(pathEvent))
        }
        let event = DocumentEvent(compound: compound)
        (pending ? pendingEventSubject : eventSubject).send(event)
    }

    func updateActivePath(nodeAndControl id: UUID, deltaInView: Vector2, pending: Bool = false) {
        updateActivePath(nodeAndControl: id, delta: deltaInView.applying(viewport.info.viewToWorld), pending: pending)
    }

    // MARK: update handler

    func onEvent(_ callback: @escaping (DocumentEvent) -> Void) {
        eventSubject.sink { value in callback(value) }.store(in: &subscriptions)
    }

    func onPendingEvent(_ callback: @escaping (DocumentEvent) -> Void) {
        pendingEventSubject.sink { value in callback(value) }.store(in: &subscriptions)
    }

    init(activePathModel: ActivePathModel, viewport: Viewport) {
        self.activePathModel = activePathModel
        self.viewport = viewport
    }

    // MARK: private

    private var subscriptions = Set<AnyCancellable>()
    private var eventSubject = PassthroughSubject<DocumentEvent, Never>()
    private var pendingEventSubject = PassthroughSubject<DocumentEvent, Never>()

    private var activePath: Path? { activePathModel.activePath }
}
