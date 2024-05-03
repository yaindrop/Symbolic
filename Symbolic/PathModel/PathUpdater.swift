import Combine
import Foundation
import SwiftUI

// MARK: - PathUpdater

class PathUpdater: ObservableObject {
    let pathStore: PathStore
    let activePathModel: ActivePathModel
    let viewport: Viewport

    func updateActivePath(splitSegment fromNodeId: UUID, paramT: CGFloat, position: Point2, pending: Bool = false) {
        guard let activePath else { return }
        handle(.pathAction(.splitSegment(.init(pathId: activePath.id, fromNodeId: fromNodeId, paramT: paramT, newNode: PathNode(position: position)))), pending: pending)
    }

    func updateActivePath(splitSegment fromNodeId: UUID, paramT: CGFloat, positionInView: Point2, pending: Bool = false) {
        updateActivePath(splitSegment: fromNodeId, paramT: paramT, position: positionInView.applying(viewport.toWorld), pending: pending)
    }

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
        case let .splitSegment(splitSegment): getEventKind(splitSegment)
        case let .moveEdge(moveEdge): getEventKind(moveEdge)
        case let .moveNode(moveNode): getEventKind(moveNode)
        case let .setEdgeArc(setEdgeArc): getEventKind(setEdgeArc)
        case let .setEdgeBezier(setEdgeBezier): getEventKind(setEdgeBezier)
        case let .setNodePosition(setNodePosition): getEventKind(setNodePosition)
        case .setEdgeLine: nil
        default: nil
        }
    }

    private func getEventKind(_ splitSegment: PathAction.SplitSegment) -> DocumentEvent.Kind? {
        let pathId = splitSegment.pathId, fromNodeId = splitSegment.fromNodeId, paramT = splitSegment.paramT, newNode = splitSegment.newNode
        guard let path = pathStore.pathIdToPath[pathId],
              let segment = path.segment(from: fromNodeId) else { return nil }
        var events: [CompoundEvent.Kind] = []
        events.append(.pathEvent(.init(in: pathId, createNodeAfter: fromNodeId, newNode)))
        var (before, after) = segment.split(paramT: paramT)
        let offset = segment.position(paramT: paramT).offset(to: newNode.position)
        if case let .bezier(b) = before.edge {
            before = before.with(edge: .bezier(b.with(control1: b.control1 + offset)))
        }
        events.append(.pathEvent(.init(in: pathId, updateEdgeFrom: fromNodeId, before.edge)))
        if case let .bezier(b) = after.edge {
            after = after.with(edge: .bezier(b.with(control0: b.control0 + offset)))
        }
        events.append(.pathEvent(.init(in: pathId, updateEdgeFrom: newNode.id, after.edge)))
        return .compoundEvent(.init(events: events))
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
        guard let path = pathStore.pathIdToPath[pathId],
              let curr = path.pair(id: nodeId) else { return nil }
        var events: [CompoundEvent.Kind] = []
        if let prev = path.pair(before: nodeId), case let .bezier(b) = prev.edge {
            let pathEvent = PathEvent(in: pathId, updateEdgeFrom: prev.node.id, .bezier(b.with(control1: b.control1 + offset)))
            events.append(.pathEvent(pathEvent))
        }
        let pathEvent = PathEvent(in: pathId, updateNode: curr.node.with(offset: offset))
        events.append(.pathEvent(pathEvent))
        if case let .bezier(b) = curr.edge {
            let pathEvent = PathEvent(in: pathId, updateEdgeFrom: nodeId, .bezier(b.with(control0: b.control0 + offset)))
            events.append(.pathEvent(pathEvent))
        }
        return .compoundEvent(.init(events: events))
    }

    private func getEventKind(_ moveEdge: PathAction.MoveEdge) -> DocumentEvent.Kind? {
        let pathId = moveEdge.pathId, fromNodeId = moveEdge.fromNodeId, offset = moveEdge.offset
        guard let path = pathStore.pathIdToPath[pathId],
              let curr = path.pair(id: fromNodeId) else { return nil }
        var events: [CompoundEvent.Kind] = []
        if let prev = path.pair(before: fromNodeId), case let .bezier(b) = prev.edge {
            let pathEvent = PathEvent(in: pathId, updateEdgeFrom: prev.node.id, .bezier(b.with(control1: b.control1 + offset)))
            events.append(.pathEvent(pathEvent))
        }
        let pathEvent = PathEvent(in: pathId, updateNode: curr.node.with(offset: offset))
        events.append(.pathEvent(pathEvent))
        if case let .bezier(b) = curr.edge {
            let pathEvent = PathEvent(in: pathId, updateEdgeFrom: fromNodeId, .bezier(b.with(offset: offset)))
            events.append(.pathEvent(pathEvent))
        }
        if let next = path.pair(after: fromNodeId) {
            let pathEvent = PathEvent(in: pathId, updateNode: next.node.with(offset: offset))
            events.append(.pathEvent(pathEvent))
            if case let .bezier(b) = next.edge {
                let pathEvent = PathEvent(in: pathId, updateEdgeFrom: next.node.id, .bezier(b.with(control1: b.control1 + offset)))
                events.append(.pathEvent(pathEvent))
            }
        }
        return .compoundEvent(.init(events: events))
    }
}
