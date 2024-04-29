import Combine
import Foundation
import SwiftUI

// MARK: - PathUpdater

class PathUpdater: ObservableObject {
    let pathStore: PathStore
    let activePathModel: ActivePathModel
    let viewport: Viewport

    // MARK: single update

    func updateActivePath(node id: UUID, position: Point2, pending: Bool = false) {
        guard let activePath else { return }
        handle(.pathAction(.setNodePosition(.init(pathId: activePath.id, nodeId: id, position: position))), pending: pending)
    }

    func updateActivePath(edge fromNodeId: UUID, bezier: PathEdge.Bezier, pending: Bool = false) {
        guard let activePath else { return }
        handle(.pathAction(.setEdgeBezier(.init(pathId: activePath.id, fromNodeId: fromNodeId, bezier: bezier))), pending: pending)
    }

    func updateActivePath(edge fromNodeId: UUID, arc: PathEdge.Arc, pending: Bool = false) {
        guard let activePath else { return }
        handle(.pathAction(.setEdgeArc(.init(pathId: activePath.id, fromNodeId: fromNodeId, arc: arc))), pending: pending)
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

    func updateActivePath(moveNode id: UUID, offset: Vector2, pending: Bool = false) {
        guard let activePath else { return }
        handle(.pathAction(.moveNode(.init(pathId: activePath.id, nodeId: id, offset: offset))), pending: pending)
    }

    func updateActivePath(moveEdge fromId: UUID, offset: Vector2, pending: Bool = false) {
        guard let activePath else { return }
        handle(.pathAction(.moveEdge(.init(pathId: activePath.id, fromNodeId: fromId, offset: offset))), pending: pending)
    }

    func updateActivePath(moveNode id: UUID, offsetInView: Vector2, pending: Bool = false) {
        updateActivePath(moveNode: id, offset: offsetInView.applying(viewport.toWorld), pending: pending)
    }

    func updateActivePath(moveEdge fromId: UUID, offsetInView: Vector2, pending: Bool = false) {
        updateActivePath(moveEdge: fromId, offset: offsetInView.applying(viewport.toWorld), pending: pending)
    }

    // MARK: update handler

    func onEvent(_ callback: @escaping (DocumentEvent) -> Void) {
        eventSubject.sink { value in callback(value) }.store(in: &subscriptions)
    }

    func onPendingEvent(_ callback: @escaping (DocumentEvent) -> Void) {
        pendingEventSubject.sink { value in callback(value) }.store(in: &subscriptions)
    }

    init(pathStore: PathStore, activePathModel: ActivePathModel, viewport: Viewport) {
        self.pathStore = pathStore
        self.activePathModel = activePathModel
        self.viewport = viewport
    }

    // MARK: private

    private var subscriptions = Set<AnyCancellable>()
    private var eventSubject = PassthroughSubject<DocumentEvent, Never>()
    private var pendingEventSubject = PassthroughSubject<DocumentEvent, Never>()

    private var activePath: Path? { activePathModel.activePath }

    private func handle(_ action: DocumentAction, pending: Bool) {
        switch action {
        case let .pathAction(pathAction):
            handle(pathAction, pending: pending)
        }
    }

    private func handle(_ pathAction: PathAction, pending: Bool) {
        guard let eventKind = getEventKind(pathAction) else { return }
        let event = DocumentEvent(kind: eventKind, action: .pathAction(pathAction))
        (pending ? pendingEventSubject : eventSubject).send(event)
    }

    private func getEventKind(_ pathAction: PathAction) -> DocumentEvent.Kind? {
        switch pathAction {
        case let .moveEdge(moveEdge): getEventKind(moveEdge)
        case let .moveNode(moveNode): getEventKind(moveNode)
        case let .setEdgeArc(setEdgeArc): getEventKind(setEdgeArc)
        case let .setEdgeBezier(setEdgeBezier): getEventKind(setEdgeBezier)
        case let .setNodePosition(setNodePosition): getEventKind(setNodePosition)
        case .setEdgeLine: nil
        default: nil
        }
    }

    private func getEventKind(_ setNodePosition: PathAction.SetNodePosition) -> DocumentEvent.Kind? {
        let pathId = setNodePosition.pathId, nodeId = setNodePosition.nodeId, position = setNodePosition.position
        guard let node = pathStore.pathIdToPath[pathId]?.node(id: nodeId) else { return nil }
        return .pathEvent(.init(in: pathId, updateNode: node.with(position: position)))
    }

    private func getEventKind(_ setEdgeBezier: PathAction.SetEdgeBezier) -> DocumentEvent.Kind? {
        let pathId = setEdgeBezier.pathId, fromNodeId = setEdgeBezier.fromNodeId, bezier = setEdgeBezier.bezier
        return .pathEvent(.init(in: pathId, updateEdgeFrom: fromNodeId, .bezier(bezier)))
    }

    private func getEventKind(_ setEdgeArc: PathAction.SetEdgeArc) -> DocumentEvent.Kind? {
        let pathId = setEdgeArc.pathId, fromNodeId = setEdgeArc.fromNodeId, arc = setEdgeArc.arc
        return .pathEvent(.init(in: pathId, updateEdgeFrom: fromNodeId, .arc(arc)))
    }

    private func getEventKind(_ moveNode: PathAction.MoveNode) -> DocumentEvent.Kind? {
        let pathId = moveNode.pathId, nodeId = moveNode.nodeId, offset = moveNode.offset
        guard let segment = pathStore.pathIdToPath[pathId]?.segment(id: nodeId) else { return nil }
        var events: [CompoundEvent.Kind] = []
        if let prevId = segment.prevId, case let .bezier(bezier) = segment.prevEdge {
            let pathEvent = PathEvent(in: pathId, updateEdgeFrom: prevId, .bezier(bezier.with(control1: bezier.control1 + offset)))
            events.append(.pathEvent(pathEvent))
        }
        let node = segment.node
        let pathEvent = PathEvent(in: pathId, updateNode: node.with(offset: offset))
        events.append(.pathEvent(pathEvent))
        if case let .bezier(bezier) = segment.edge {
            let pathEvent = PathEvent(in: pathId, updateEdgeFrom: nodeId, .bezier(bezier.with(control0: bezier.control0 + offset)))
            events.append(.pathEvent(pathEvent))
        }
        return .compoundEvent(.init(events: events))
    }

    private func getEventKind(_ moveEdge: PathAction.MoveEdge) -> DocumentEvent.Kind? {
        let pathId = moveEdge.pathId, fromNodeId = moveEdge.fromNodeId, offset = moveEdge.offset
        guard let segment = pathStore.pathIdToPath[pathId]?.segment(id: fromNodeId) else { return nil }
        var events: [CompoundEvent.Kind] = []
        if let prevId = segment.prevId, case let .bezier(bezier) = segment.prevEdge {
            let pathEvent = PathEvent(in: pathId, updateEdgeFrom: prevId, .bezier(bezier.with(control1: bezier.control1 + offset)))
            events.append(.pathEvent(pathEvent))
        }
        let node = segment.node
        let pathEvent = PathEvent(in: pathId, updateNode: node.with(offset: offset))
        events.append(.pathEvent(pathEvent))
        if case let .bezier(bezier) = segment.edge {
            let pathEvent = PathEvent(in: pathId, updateEdgeFrom: fromNodeId, .bezier(bezier.with(offset: offset)))
            events.append(.pathEvent(pathEvent))
        }
        if let nextNode = segment.nextNode {
            let pathEvent = PathEvent(in: pathId, updateNode: nextNode.with(offset: offset))
            events.append(.pathEvent(pathEvent))
        }
        if let nextId = segment.nextId, case let .bezier(bezier) = segment.nextEdge {
            let pathEvent = PathEvent(in: pathId, updateEdgeFrom: nextId, .bezier(bezier.with(control1: bezier.control1 + offset)))
            events.append(.pathEvent(pathEvent))
        }
        return .compoundEvent(.init(events: events))
    }
}
