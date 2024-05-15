import Combine
import Foundation
import SwiftUI

@Observable
class PathUpdateModel {
    func onEvent(_ callback: @escaping (DocumentEvent) -> Void) {
        eventSubject.sink(receiveValue: callback).store(in: &subscriptions)
    }

    func onPendingEvent(_ callback: @escaping (DocumentEvent) -> Void) {
        pendingEventSubject.sink(receiveValue: callback).store(in: &subscriptions)
    }

    @ObservationIgnored fileprivate var subscriptions = Set<AnyCancellable>()

    @ObservationIgnored fileprivate let eventSubject = PassthroughSubject<DocumentEvent, Never>()
    @ObservationIgnored fileprivate let pendingEventSubject = PassthroughSubject<DocumentEvent, Never>()
}

// MARK: - PathUpdater

struct PathUpdater {
    let pathModel: PathModel
    let pendingPathModel: PendingPathModel
    let activePathModel: ActivePathModel
    let model: PathUpdateModel

    func updateActivePath(splitSegment fromNodeId: UUID, paramT: Scalar, newNodeId: UUID, position: Point2, pending: Bool = false) {
        guard let activePath else { return }
        let newNode = PathNode(id: newNodeId, position: position)
        handle(.pathAction(.splitSegment(.init(pathId: activePath.id, fromNodeId: fromNodeId, paramT: paramT, newNode: newNode))), pending: pending)
    }

    func updateActivePath(deleteNode id: UUID) {
        guard let activePath else { return }
        handle(.pathAction(.deleteNode(.init(pathId: activePath.id, nodeId: id))), pending: false)
    }

    func updateActivePath(breakAtNode id: UUID) {
        guard let activePath else { return }
        handle(.pathAction(.breakAtNode(.init(pathId: activePath.id, nodeId: id))), pending: false)
    }

    func updateActivePath(deleteEdge fromNodeId: UUID) {
        guard let activePath else { return }
        handle(.pathAction(.breakAtEdge(.init(pathId: activePath.id, fromNodeId: fromNodeId))), pending: false)
    }

    func updateActivePath(changeEdge fromNodeId: UUID, to: PathEdge.Case) {
        guard let activePath else { return }
        handle(.pathAction(.changeEdge(.init(pathId: activePath.id, fromNodeId: fromNodeId, to: to))), pending: false)
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

    // MARK: compound update

    func updateActivePath(moveNode id: UUID, offset: Vector2, pending: Bool = false) {
        guard let activePath else { return }
        handle(.pathAction(.moveNode(.init(pathId: activePath.id, nodeId: id, offset: offset))), pending: pending)
    }

    func updateActivePath(moveEdge fromId: UUID, offset: Vector2, pending: Bool = false) {
        guard let activePath else { return }
        handle(.pathAction(.moveEdge(.init(pathId: activePath.id, fromNodeId: fromId, offset: offset))), pending: pending)
    }

    func updateActivePath(moveByOffset offset: Vector2, pending: Bool = false) {
        guard let activePath else { return }
        handle(.pathAction(.movePath(.init(pathId: activePath.id, offset: offset))), pending: pending)
    }

    // MARK: private

    private var activePath: Path? { service.activePath.activePath }

    // MARK: handle action

    private func handle(_ action: DocumentAction, pending: Bool) {
        let _r = tracer.range("[path-updater] handle action, pending: \(pending)", type: .intent); defer { _r() }
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
        if pending || pendingPathModel.hasPendingEvent {
            let _r = tracer.range("Path updater send pending event"); defer { _r() }
            model.pendingEventSubject.send(event)
        }
        if !pending {
            let _r = tracer.range("Path updater send event"); defer { _r() }
            model.eventSubject.send(event)
        }
    }

    // MARK: collect events for action

    private func collectEvents(to events: inout [PathEvent], _ pathAction: PathAction) {
        switch pathAction {
        case .load: break
        case let .splitSegment(splitSegment): collectEvents(to: &events, splitSegment)
        case let .deleteNode(deleteNode): collectEvents(to: &events, deleteNode)
        case let .breakAtEdge(breakAtEdge): collectEvents(to: &events, breakAtEdge)
        case let .breakAtNode(breakAtNode): collectEvents(to: &events, breakAtNode)
        case let .changeEdge(changeEdge): collectEvents(to: &events, changeEdge)
        case let .setEdgeArc(setEdgeArc): collectEvents(to: &events, setEdgeArc)
        case let .setEdgeBezier(setEdgeBezier): collectEvents(to: &events, setEdgeBezier)
        case let .setNodePosition(setNodePosition): collectEvents(to: &events, setNodePosition)
        case .setEdgeLine: break
        case let .moveEdge(moveEdge): collectEvents(to: &events, moveEdge)
        case let .moveNode(moveNode): collectEvents(to: &events, moveNode)
        case let .movePath(movePath): collectEvents(to: &events, movePath)
        }
    }

    private func collectEvents(to events: inout [PathEvent], _ splitSegment: PathAction.SplitSegment) {
        let pathId = splitSegment.pathId, fromNodeId = splitSegment.fromNodeId, paramT = splitSegment.paramT, newNode = splitSegment.newNode
        guard let path = pathModel.pathMap[pathId],
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

    private func collectEvents(to events: inout [PathEvent], _ deleteNode: PathAction.DeleteNode) {
        let pathId = deleteNode.pathId, nodeId = deleteNode.nodeId
        events.append(.init(in: pathId, deleteNode: nodeId))
    }

    private func collectEvents(to events: inout [PathEvent], _ breakAtEdge: PathAction.BreakAtEdge) {
        let pathId = breakAtEdge.pathId, fromNodeId = breakAtEdge.fromNodeId
        guard let path = pathModel.pathMap[pathId] else { return }
        if path.isClosed {
            events.append(.init(in: pathId, breakAfter: fromNodeId))
            return
        }
        guard let i = path.nodeIndex(id: fromNodeId) else { return }
        if i < path.count / 2 {
            events.append(.init(in: pathId, breakUntil: fromNodeId))
            let newPairs = path.pairs.with { $0.mutateKeys { $0 = Array($0[...i]) } }
            events.append(.create(.init(path: Path(pairs: newPairs, isClosed: false))))
        } else {
            events.append(.init(in: pathId, breakAfter: fromNodeId))
            let newPairs = path.pairs.with { $0.mutateKeys { $0 = Array($0[(i + 1)...]) } }
            events.append(.create(.init(path: Path(pairs: newPairs, isClosed: false))))
        }
    }

    private func collectEvents(to events: inout [PathEvent], _ breakAtNode: PathAction.BreakAtNode) {
        let pathId = breakAtNode.pathId, nodeId = breakAtNode.nodeId
        guard let path = pathModel.pathMap[pathId] else { return }
        if path.isClosed {
            guard let prevNode = path.node(before: nodeId) else { return }
            events.append(.init(in: pathId, breakAfter: prevNode.id))
            events.append(.init(in: pathId, breakUntil: nodeId))
            return
        }
        guard let i = path.nodeIndex(id: nodeId) else { return }
        if i < path.count / 2 {
            events.append(.init(in: pathId, breakUntil: nodeId))
            if i - 1 > 0 {
                let newPairs = path.pairs.with { $0.mutateKeys { $0 = Array($0[...(i - 1)]) } }
                events.append(.create(.init(path: Path(pairs: newPairs, isClosed: false))))
            }
        } else {
            guard let prevNode = path.node(before: nodeId) else { return }
            events.append(.init(in: pathId, breakAfter: prevNode.id))
            if i + 1 < path.count - 1 {
                let newPairs = path.pairs.with { $0.mutateKeys { $0 = Array($0[(i + 1)...]) } }
                events.append(.create(.init(path: Path(pairs: newPairs, isClosed: false))))
            }
        }
    }

    private func collectEvents(to events: inout [PathEvent], _ setNodePosition: PathAction.SetNodePosition) {
        let pathId = setNodePosition.pathId, nodeId = setNodePosition.nodeId, position = setNodePosition.position
        guard let node = pathModel.pathMap[pathId]?.node(id: nodeId) else { return }
        events.append(.init(in: pathId, updateNode: node.with(position: position)))
    }

    private func collectEvents(to events: inout [PathEvent], _ changeEdge: PathAction.ChangeEdge) {
        let pathId = changeEdge.pathId, fromNodeId = changeEdge.fromNodeId, to = changeEdge.to
        guard let path = pathModel.pathMap[pathId],
              let segment = path.segment(from: fromNodeId) else { return }
        switch to {
        case .arc: events.append(.init(in: pathId, updateEdgeFrom: fromNodeId, .arc(.init(radius: CGSize(10, 10), rotation: .zero, largeArc: false, sweep: false))))
        case .bezier: events.append(.init(in: pathId, updateEdgeFrom: fromNodeId, .bezier(.init(control0: segment.from, control1: segment.to))))
        case .line: events.append(.init(in: pathId, updateEdgeFrom: fromNodeId, .line(.init())))
        }
    }

    private func collectEvents(to events: inout [PathEvent], _ setEdgeArc: PathAction.SetEdgeArc) {
        let pathId = setEdgeArc.pathId, fromNodeId = setEdgeArc.fromNodeId, arc = setEdgeArc.arc
        events.append(.init(in: pathId, updateEdgeFrom: fromNodeId, .arc(arc)))
    }

    private func collectEvents(to events: inout [PathEvent], _ setEdgeBezier: PathAction.SetEdgeBezier) {
        let pathId = setEdgeBezier.pathId, fromNodeId = setEdgeBezier.fromNodeId, bezier = setEdgeBezier.bezier
        events.append(.init(in: pathId, updateEdgeFrom: fromNodeId, .bezier(bezier)))
    }

    private func collectEvents(to events: inout [PathEvent], _ moveNode: PathAction.MoveNode) {
        let pathId = moveNode.pathId, nodeId = moveNode.nodeId, offset = moveNode.offset
        guard let path = pathModel.pathMap[pathId],
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
        guard let path = pathModel.pathMap[pathId],
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

    private func collectEvents(to events: inout [PathEvent], _ movePath: PathAction.MovePath) {
        let pathId = movePath.pathId, offset = movePath.offset
        events.append(.init(in: pathId, move: offset))
    }
}

// MARK: - PathUpdaterInView

struct PathUpdaterInView {
    let viewport: ViewportModel
    let pathModel: PathModel
    let pendingPathModel: PendingPathModel
    let activePathModel: ActivePathModel
    let pathUpdateModel: PathUpdateModel

    func updateActivePath(splitSegment fromNodeId: UUID, paramT: Scalar, newNodeId: UUID, position: Point2, pending: Bool = false) {
        service.pathUpdater.updateActivePath(splitSegment: fromNodeId, paramT: paramT, newNodeId: newNodeId, position: position.applying(viewport.toWorld), pending: pending)
    }

    // MARK: single update

    func updateActivePath(node id: UUID, position: Point2, pending: Bool = false) {
        service.pathUpdater.updateActivePath(node: id, position: position.applying(viewport.toWorld), pending: pending)
    }

    func updateActivePath(edge fromNodeId: UUID, bezier: PathEdge.Bezier, pending: Bool = false) {
        service.pathUpdater.updateActivePath(edge: fromNodeId, bezier: bezier.applying(viewport.toWorld), pending: pending)
    }

    func updateActivePath(edge fromNodeId: UUID, arc: PathEdge.Arc, pending: Bool = false) {
        service.pathUpdater.updateActivePath(edge: fromNodeId, arc: arc.applying(viewport.toWorld), pending: pending)
    }

    // MARK: compound update

    func updateActivePath(moveNode id: UUID, offset: Vector2, pending: Bool = false) {
        service.pathUpdater.updateActivePath(moveNode: id, offset: offset.applying(viewport.toWorld), pending: pending)
    }

    func updateActivePath(moveEdge fromId: UUID, offset: Vector2, pending: Bool = false) {
        service.pathUpdater.updateActivePath(moveEdge: fromId, offset: offset.applying(viewport.toWorld), pending: pending)
    }

    func updateActivePath(moveByOffset offset: Vector2, pending: Bool = false) {
        service.pathUpdater.updateActivePath(moveByOffset: offset.applying(viewport.toWorld), pending: pending)
    }
}
