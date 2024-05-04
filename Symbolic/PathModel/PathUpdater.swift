import Combine
import Foundation
import SwiftUI

// MARK: - PathUpdater

class PathUpdater: ObservableObject {
    let pathStore: PathStore
    let activePathModel: ActivePathModel
    let viewport: Viewport

    func updateActivePath(splitSegment fromNodeId: UUID, paramT: Scalar, newNodeId: UUID, position: Point2, pending: Bool = false) {
        guard let activePath else { return }
        let newNode = PathNode(id: newNodeId, position: position)
        handle(.pathAction(.splitSegment(.init(pathId: activePath.id, fromNodeId: fromNodeId, paramT: paramT, newNode: newNode))), pending: pending)
    }

    func updateActivePath(splitSegment fromNodeId: UUID, paramT: Scalar, newNodeId: UUID, positionInView: Point2, pending: Bool = false) {
        updateActivePath(splitSegment: fromNodeId, paramT: paramT, newNodeId: newNodeId, position: positionInView.applying(viewport.toWorld), pending: pending)
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

    // MARK: handle action

    private func handle(_ action: DocumentAction, pending: Bool) {
        switch action {
        case let .pathAction(pathAction):
            handle(pathAction, pending: pending)
        }
    }

    private func handle(_ pathAction: PathAction, pending: Bool) {
        var events: [PathEvent] = []
        collectEvents(to: &events, pathAction)
        var kind: DocumentEvent.Kind
        if events.isEmpty {
            return
        } else if events.count == 1 {
            kind = .pathEvent(events.first!)
        } else {
            kind = .compoundEvent(.init(events: events.map { .pathEvent($0) }))
        }
        let event = DocumentEvent(kind: kind, action: .pathAction(pathAction))
        (pending ? pendingEventSubject : eventSubject).send(event)
    }

    // MARK: collect events for action

    private func collectEvents(to events: inout [PathEvent], _ pathAction: PathAction) {
        switch pathAction {
        case let .splitSegment(splitSegment): collectEvents(to: &events, splitSegment)
        case let .moveEdge(moveEdge): collectEvents(to: &events, moveEdge)
        case let .moveNode(moveNode): collectEvents(to: &events, moveNode)
        case let .setEdgeArc(setEdgeArc): collectEvents(to: &events, setEdgeArc)
        case let .setEdgeBezier(setEdgeBezier): collectEvents(to: &events, setEdgeBezier)
        case let .setNodePosition(setNodePosition): collectEvents(to: &events, setNodePosition)
        case .setEdgeLine: break
        default: break
        }
    }

    private func collectEvents(to events: inout [PathEvent], _ splitSegment: PathAction.SplitSegment) {
        let pathId = splitSegment.pathId, fromNodeId = splitSegment.fromNodeId, paramT = splitSegment.paramT, newNode = splitSegment.newNode
        guard let path = pathStore.pathIdToPath[pathId],
              let segment = path.segment(from: fromNodeId) else { return }
        events.append(.init(in: pathId, createNodeAfter: fromNodeId, newNode))
        var (before, after) = segment.split(paramT: paramT)
        let offset = segment.position(paramT: paramT).offset(to: newNode.position)
        if case let .bezier(b) = before.edge {
            before = before.with(edge: .bezier(b.with(control1: b.control1 + offset)))
        }
        events.append(.init(in: pathId, updateEdgeFrom: fromNodeId, before.edge))
        if case let .bezier(b) = after.edge {
            after = after.with(edge: .bezier(b.with(control0: b.control0 + offset)))
        }
        events.append(.init(in: pathId, updateEdgeFrom: newNode.id, after.edge))
    }

    private func collectEvents(to events: inout [PathEvent], _ setNodePosition: PathAction.SetNodePosition) {
        let pathId = setNodePosition.pathId, nodeId = setNodePosition.nodeId, position = setNodePosition.position
        guard let node = pathStore.pathIdToPath[pathId]?.node(id: nodeId) else { return }
        events.append(.init(in: pathId, updateNode: node.with(position: position)))
    }

    private func collectEvents(to events: inout [PathEvent], _ setEdgeBezier: PathAction.SetEdgeBezier) {
        let pathId = setEdgeBezier.pathId, fromNodeId = setEdgeBezier.fromNodeId, bezier = setEdgeBezier.bezier
        events.append(.init(in: pathId, updateEdgeFrom: fromNodeId, .bezier(bezier)))
    }

    private func collectEvents(to events: inout [PathEvent], _ setEdgeArc: PathAction.SetEdgeArc) {
        let pathId = setEdgeArc.pathId, fromNodeId = setEdgeArc.fromNodeId, arc = setEdgeArc.arc
        events.append(.init(in: pathId, updateEdgeFrom: fromNodeId, .arc(arc)))
    }

    private func collectEvents(to events: inout [PathEvent], _ moveNode: PathAction.MoveNode) {
        let pathId = moveNode.pathId, nodeId = moveNode.nodeId, offset = moveNode.offset
        guard let path = pathStore.pathIdToPath[pathId],
              let curr = path.pair(id: nodeId) else { return }
        if let prev = path.pair(before: nodeId), case let .bezier(b) = prev.edge {
            events.append(.init(in: pathId, updateEdgeFrom: prev.node.id, .bezier(b.with(control1: b.control1 + offset))))
        }
        events.append(.init(in: pathId, updateNode: curr.node.with(offset: offset)))
        if case let .bezier(b) = curr.edge {
            events.append(.init(in: pathId, updateEdgeFrom: nodeId, .bezier(b.with(control0: b.control0 + offset))))
        }
    }

    private func collectEvents(to events: inout [PathEvent], _ moveEdge: PathAction.MoveEdge) {
        let pathId = moveEdge.pathId, fromNodeId = moveEdge.fromNodeId, offset = moveEdge.offset
        guard let path = pathStore.pathIdToPath[pathId],
              let curr = path.pair(id: fromNodeId) else { return }
        if let prev = path.pair(before: fromNodeId), case let .bezier(b) = prev.edge {
            events.append(.init(in: pathId, updateEdgeFrom: prev.node.id, .bezier(b.with(offset1: offset))))
        }
        events.append(.init(in: pathId, updateNode: curr.node.with(offset: offset)))
        if case let .bezier(b) = curr.edge {
            events.append(.init(in: pathId, updateEdgeFrom: fromNodeId, .bezier(b.with(offset: offset))))
        }
        if let next = path.pair(after: fromNodeId) {
            events.append(.init(in: pathId, updateNode: next.node.with(offset: offset)))
            if case let .bezier(b) = next.edge {
                events.append(.init(in: pathId, updateEdgeFrom: next.node.id, .bezier(b.with(offset0: offset))))
            }
        }
    }
}
