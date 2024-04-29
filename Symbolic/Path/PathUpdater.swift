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

    func updateActivePath(edge fromNodeId: UUID, bezier: PathEdge.Bezier, pending: Bool = false) {
        guard let activePath else { return }
        let pathEvent = PathEvent(in: activePath.id, updateEdgeFrom: fromNodeId, .bezier(bezier))
        let event = DocumentEvent(kind: .pathEvent(pathEvent))
        (pending ? pendingEventSubject : eventSubject).send(event)
    }

    func updateActivePath(edge fromNodeId: UUID, arc: PathEdge.Arc, pending: Bool = false) {
        guard let activePath else { return }
        let pathEvent = PathEvent(in: activePath.id, updateEdgeFrom: fromNodeId, .arc(arc))
        let event = DocumentEvent(kind: .pathEvent(pathEvent))
        (pending ? pendingEventSubject : eventSubject).send(event)
    }

    func updateActivePath(node id: UUID, positionInView: Point2, pending: Bool = false) {
        updateActivePath(node: id, position: positionInView.applying(viewport.toWorld), pending: pending)
    }

    func updateActivePath(edge fromNodeId: UUID, bezierInView: PathEdge.Bezier, pending: Bool = false) {
        updateActivePath(edge: fromNodeId, bezier: bezierInView.applying(viewport.toWorld), pending: pending)
    }

    func updateActivePath(edge fromNodeId: UUID, arcInView: PathEdge.Arc, pending: Bool = false) {
        updateActivePath(edge: fromNodeId, arc: arcInView.applying(viewport.toWorld), pending: pending)
    }

    // MARK: compound update

    func updateActivePath(aroundNode id: UUID, offset: Vector2, pending: Bool = false) {
        guard let activePath,
              let segment = activePath.segment(id: id) else { return }
        var compound: [CompoundEventKind] = []
        if let prevId = segment.prevId, case let .bezier(bezier) = segment.prevEdge {
            let pathEvent = PathEvent(in: activePath.id, updateEdgeFrom: prevId, .bezier(bezier.with(control1: bezier.control1 + offset)))
            compound.append(.pathEvent(pathEvent))
        }
        let node = segment.node
        let pathEvent = PathEvent(in: activePath.id, updateNode: node.with(offset: offset))
        compound.append(.pathEvent(pathEvent))
        if case let .bezier(bezier) = segment.edge {
            let pathEvent = PathEvent(in: activePath.id, updateEdgeFrom: id, .bezier(bezier.with(control0: bezier.control0 + offset)))
            compound.append(.pathEvent(pathEvent))
        }
        let event = DocumentEvent(compound: compound)
        (pending ? pendingEventSubject : eventSubject).send(event)
    }

    func updateActivePath(aroundEdge id: UUID, offset: Vector2, pending: Bool = false) {
        guard let activePath,
              let segment = activePath.segment(id: id) else { return }
        var compound: [CompoundEventKind] = []
        if let prevId = segment.prevId, case let .bezier(bezier) = segment.prevEdge {
            let pathEvent = PathEvent(in: activePath.id, updateEdgeFrom: prevId, .bezier(bezier.with(control1: bezier.control1 + offset)))
            compound.append(.pathEvent(pathEvent))
        }
        let node = segment.node
        let pathEvent = PathEvent(in: activePath.id, updateNode: node.with(offset: offset))
        compound.append(.pathEvent(pathEvent))
        if case let .bezier(bezier) = segment.edge {
            let pathEvent = PathEvent(in: activePath.id, updateEdgeFrom: id, .bezier(bezier.with(offset: offset)))
            compound.append(.pathEvent(pathEvent))
        }
        if let nextNode = segment.nextNode {
            let pathEvent = PathEvent(in: activePath.id, updateNode: nextNode.with(offset: offset))
            compound.append(.pathEvent(pathEvent))
        }
        if let nextId = segment.nextId, case let .bezier(bezier) = segment.nextEdge {
            let pathEvent = PathEvent(in: activePath.id, updateEdgeFrom: nextId, .bezier(bezier.with(control1: bezier.control1 + offset)))
            compound.append(.pathEvent(pathEvent))
        }
        let event = DocumentEvent(compound: compound)
        print("event", event)
        (pending ? pendingEventSubject : eventSubject).send(event)
    }

    func updateActivePath(aroundNode id: UUID, offsetInView: Vector2, pending: Bool = false) {
        updateActivePath(aroundNode: id, offset: offsetInView.applying(viewport.toWorld), pending: pending)
    }

    func updateActivePath(aroundEdge id: UUID, offsetInView: Vector2, pending: Bool = false) {
        updateActivePath(aroundEdge: id, offset: offsetInView.applying(viewport.toWorld), pending: pending)
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
