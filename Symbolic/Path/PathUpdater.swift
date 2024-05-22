import Combine
import Foundation
import SwiftUI

fileprivate let pathUpdaterTracer = tracer.tagged("active-path")

class PathUpdateStore: Store {
    fileprivate var subscriptions = Set<AnyCancellable>()

    fileprivate let eventSubject = PassthroughSubject<DocumentEvent, Never>()
    fileprivate let pendingEventSubject = PassthroughSubject<DocumentEvent?, Never>()
}

// MARK: - PathUpdater

struct PathUpdater {
    let pathStore: PathStore
    let pendingPathStore: PendingPathStore
    let activePathService: ActivePathService
    let viewport: ViewportService
    let grid: CanvasGridStore
    let store: PathUpdateStore

    func onEvent(_ callback: @escaping (DocumentEvent) -> Void) {
        store.eventSubject.sink(receiveValue: callback).store(in: &store.subscriptions)
    }

    func onPendingEvent(_ callback: @escaping (DocumentEvent?) -> Void) {
        store.pendingEventSubject.sink(receiveValue: callback).store(in: &store.subscriptions)
    }
}

// MARK: action builder

extension PathUpdater {
    func updateActivePath(action kind: PathAction.Single.Kind, pending: Bool = false) {
        guard let activePath else { return }
        handle(.pathAction(.single(.init(pathId: activePath.id, kind: kind))), pending: pending)
    }

    func updateActivePathInView(action kind: PathAction.Single.Kind, pending: Bool = false) {
        let toWorld = viewport.toWorld
        var action: PathAction.Single.Kind {
            switch kind {
            case let .addEndingNode(kind): .addEndingNode(.init(endingNodeId: kind.endingNodeId, newNodeId: kind.newNodeId, offset: kind.offset.applying(toWorld)))
            case let .splitSegment(kind): .splitSegment(.init(fromNodeId: kind.fromNodeId, paramT: kind.paramT, newNodeId: kind.newNodeId, offset: kind.offset.applying(toWorld)))

            case let .movePath(kind): .movePath(.init(offset: kind.offset.applying(toWorld)))
            case let .moveNode(kind): .moveNode(.init(nodeId: kind.nodeId, offset: kind.offset.applying(toWorld)))
            case let .moveEdge(kind): .moveEdge(.init(fromNodeId: kind.fromNodeId, offset: kind.offset.applying(toWorld)))
            case let .moveEdgeBezier(kind): .moveEdgeBezier(.init(fromNodeId: kind.fromNodeId, offset0: kind.offset0.applying(toWorld), offset1: kind.offset1.applying(toWorld)))

            default: kind
            }
        }
        updateActivePath(action: action, pending: pending)
    }

    func update(action: PathAction.MovePaths, pending: Bool = false) {
        handle(.pathAction(.movePaths(action)), pending: pending)
    }

    func updateInView(action: PathAction.MovePaths, pending: Bool = false) {
        let action = PathAction.MovePaths(pathIds: action.pathIds, offset: action.offset.applying(viewport.toWorld))
        update(action: action, pending: pending)
    }

    func delete(pathIds: [UUID]) {
        handle(.pathAction(.deletePaths(.init(pathIds: pathIds))), pending: false)
    }

    private var activePath: Path? { activePathService.activePath }
}

// MARK: action handler

extension PathUpdater {
    private func handle(_ action: DocumentAction, pending: Bool) {
        let _r = pathUpdaterTracer.range("handle action, pending: \(pending)", type: .intent); defer { _r() }
        switch action {
        case let .pathAction(pathAction):
            handle(pathAction, pending: pending)
        }
    }

    private func handle(_ pathAction: PathAction, pending: Bool) {
        var events: [PathEvent] = []
        collectEvents(to: &events, pathAction)
        guard !events.isEmpty else {
            if pending {
                store.pendingEventSubject.send(nil)
            }
            return
        }

        var kind: DocumentEvent.Kind
        if events.count == 1 {
            kind = .pathEvent(events.first!)
        } else {
            kind = .compoundEvent(.init(events: events.map { .pathEvent($0) }))
        }

        let event = DocumentEvent(kind: kind, action: .pathAction(pathAction))
        if pending || pendingPathStore.hasPendingEvent {
            let _r = pathUpdaterTracer.range("send pending event"); defer { _r() }
            store.pendingEventSubject.send(event)
        }
        if !pending {
            let _r = pathUpdaterTracer.range("send event"); defer { _r() }
            store.eventSubject.send(event)
        }
    }
}

// MARK: collect events for action

extension PathUpdater {
    private func collectEvents(to events: inout [PathEvent], _ pathAction: PathAction) {
        switch pathAction {
        case .create: break
        case .load: break
        case let .single(single):
            switch single.kind {
            case let .addEndingNode(action): collectEvents(to: &events, pathId: single.pathId, action)
            case let .splitSegment(action): collectEvents(to: &events, pathId: single.pathId, action)

            case let .deleteNode(action): collectEvents(to: &events, pathId: single.pathId, action)
            case let .breakAtNode(action): collectEvents(to: &events, pathId: single.pathId, action)
            case let .breakAtEdge(action): collectEvents(to: &events, pathId: single.pathId, action)

            case let .setNodePosition(action): collectEvents(to: &events, pathId: single.pathId, action)
            case let .setEdge(action): collectEvents(to: &events, pathId: single.pathId, action)
            case let .changeEdge(action): collectEvents(to: &events, pathId: single.pathId, action)

            case let .movePath(action): collectEvents(to: &events, pathId: single.pathId, action)
            case let .moveNode(action): collectEvents(to: &events, pathId: single.pathId, action)
            case let .moveEdge(action): collectEvents(to: &events, pathId: single.pathId, action)
            case let .moveEdgeBezier(action): collectEvents(to: &events, pathId: single.pathId, action)
            }
        case let .movePaths(movePaths): collectEvents(to: &events, movePaths)
        case let .deletePaths(deletePaths): collectEvents(to: &events, deletePaths)
        }
    }

    private func collectEvents(to events: inout [PathEvent], pathId: UUID, _ action: PathAction.Single.AddEndingNode) {
        let endingNodeId = action.endingNodeId, newNodeId = action.newNodeId, offset = action.offset
        guard let path = pathStore.pathMap.getValue(key: pathId),
              let endingNode = path.node(id: endingNodeId) else { return }
        let prevNodeId: UUID?
        if path.isFirstNode(id: endingNodeId) {
            prevNodeId = nil
        } else if path.isLastNode(id: endingNodeId) {
            prevNodeId = endingNodeId
        } else {
            return
        }
        let snappedOffset = endingNode.position.offset(to: grid.snap(endingNode.position + offset))
        guard !snappedOffset.isZero else { return }
        events.append(.init(in: pathId, createNodeAfter: prevNodeId, .init(id: newNodeId, position: endingNode.position + snappedOffset)))
    }

    private func collectEvents(to events: inout [PathEvent], pathId: UUID, _ action: PathAction.Single.SplitSegment) {
        let fromNodeId = action.fromNodeId, paramT = action.paramT, newNodeId = action.newNodeId, offset = action.offset
        guard let path = pathStore.pathMap.getValue(key: pathId),
              let segment = path.segment(from: fromNodeId) else { return }
        let position = segment.position(paramT: paramT)
        var (before, after) = segment.split(paramT: paramT)
        let snappedOffset = position.offset(to: grid.snap(position + offset))

        events.append(.init(in: pathId, createNodeAfter: fromNodeId, .init(id: newNodeId, position: position + snappedOffset)))
        if case let .bezier(b) = before.edge {
            before = before.with(edge: .bezier(b.with(control1: b.control1 + snappedOffset)))
        }
        events.append(.init(in: pathId, updateEdgeFrom: fromNodeId, before.edge))
        if case let .bezier(b) = after.edge {
            after = after.with(edge: .bezier(b.with(control0: b.control0 + snappedOffset)))
        }
        events.append(.init(in: pathId, updateEdgeFrom: newNodeId, after.edge))
    }

    private func collectEvents(to events: inout [PathEvent], pathId: UUID, _ action: PathAction.Single.DeleteNode) {
        let nodeId = action.nodeId
        events.append(.init(in: pathId, deleteNode: nodeId))
    }

    private func collectEvents(to events: inout [PathEvent], pathId: UUID, _ action: PathAction.Single.BreakAtEdge) {
        let fromNodeId = action.fromNodeId
        guard let path = pathStore.pathMap.getValue(key: pathId) else { return }
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

    private func collectEvents(to events: inout [PathEvent], pathId: UUID, _ action: PathAction.Single.BreakAtNode) {
        let nodeId = action.nodeId
        guard let path = pathStore.pathMap.getValue(key: pathId) else { return }
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

    private func collectEvents(to events: inout [PathEvent], pathId: UUID, _ action: PathAction.Single.SetNodePosition) {
        let nodeId = action.nodeId, position = action.position
        guard let node = pathStore.pathMap.getValue(key: pathId)?.node(id: nodeId) else { return }
        events.append(.init(in: pathId, updateNode: node.with(position: position)))
    }

    private func collectEvents(to events: inout [PathEvent], pathId: UUID, _ action: PathAction.Single.SetEdge) {
        let fromNodeId = action.fromNodeId, edge = action.edge
        events.append(.init(in: pathId, updateEdgeFrom: fromNodeId, edge))
    }

    private func collectEvents(to events: inout [PathEvent], pathId: UUID, _ action: PathAction.Single.ChangeEdge) {
        let fromNodeId = action.fromNodeId, to = action.to
        guard let path = pathStore.pathMap.getValue(key: pathId),
              let segment = path.segment(from: fromNodeId) else { return }
        switch to {
        case .arc: events.append(.init(in: pathId, updateEdgeFrom: fromNodeId, .arc(.init(radius: CGSize(10, 10), rotation: .zero, largeArc: false, sweep: false))))
        case .bezier: events.append(.init(in: pathId, updateEdgeFrom: fromNodeId, .bezier(.init(control0: segment.from, control1: segment.to))))
        case .line: events.append(.init(in: pathId, updateEdgeFrom: fromNodeId, .line(.init())))
        }
    }

    private func collectEvents(to events: inout [PathEvent], pathId: UUID, _ action: PathAction.Single.MovePath) {
        let offset = action.offset
        guard let path = pathStore.pathMap.getValue(key: pathId) else { return }

        let position = path.boundingRect.minPoint
        let snappedOffset = position.offset(to: grid.snap(position + offset))
        guard !snappedOffset.isZero else { return }

        events.append(.init(in: pathId, move: snappedOffset))
    }

    private func collectEvents(to events: inout [PathEvent], pathId: UUID, _ action: PathAction.Single.MoveNode) {
        let nodeId = action.nodeId, offset = action.offset
        guard let path = pathStore.pathMap.getValue(key: pathId),
              let curr = path.pair(id: nodeId) else { return }
        let snappedOffset = curr.node.position.offset(to: grid.snap(curr.node.position + offset))
        guard !snappedOffset.isZero else { return }

        if let prev = path.pair(before: nodeId), case let .bezier(b) = prev.edge {
            events.append(.init(in: pathId, updateEdgeFrom: prev.node.id, .bezier(b.with(control1: b.control1 + snappedOffset))))
        }
        events.append(.init(in: pathId, updateNode: curr.node.with(offset: snappedOffset)))
        if case let .bezier(b) = curr.edge {
            events.append(.init(in: pathId, updateEdgeFrom: nodeId, .bezier(b.with(control0: b.control0 + snappedOffset))))
        }
    }

    private func collectEvents(to events: inout [PathEvent], pathId: UUID, _ action: PathAction.Single.MoveEdge) {
        let fromNodeId = action.fromNodeId, offset = action.offset
        guard let path = pathStore.pathMap.getValue(key: pathId),
              let curr = path.pair(id: fromNodeId) else { return }
        let snappedOffset = curr.node.position.offset(to: grid.snap(curr.node.position + offset))
        guard !snappedOffset.isZero else { return }

        if let prev = path.pair(before: fromNodeId), case let .bezier(b) = prev.edge {
            events.append(.init(in: pathId, updateEdgeFrom: prev.node.id, .bezier(b.with(offset1: snappedOffset))))
        }
        events.append(.init(in: pathId, updateNode: curr.node.with(offset: snappedOffset)))
        if case let .bezier(b) = curr.edge {
            events.append(.init(in: pathId, updateEdgeFrom: fromNodeId, .bezier(b.with(offset: snappedOffset))))
        }
        if let next = path.pair(after: fromNodeId) {
            events.append(.init(in: pathId, updateNode: next.node.with(offset: snappedOffset)))
            if case let .bezier(b) = next.edge {
                events.append(.init(in: pathId, updateEdgeFrom: next.node.id, .bezier(b.with(offset0: snappedOffset))))
            }
        }
    }

    private func collectEvents(to events: inout [PathEvent], pathId: UUID, _ action: PathAction.Single.MoveEdgeBezier) {
        let fromNodeId = action.fromNodeId, offset0 = action.offset0, offset1 = action.offset1
        guard let path = pathStore.pathMap.getValue(key: pathId),
              let curr = path.edge(id: fromNodeId),
              case let .bezier(bezier) = curr else { return }
        let snappedOffset0 = offset0 == .zero ? .zero : bezier.control0.offset(to: grid.snap(bezier.control0 + offset0))
        let snappedOffset1 = offset1 == .zero ? .zero : bezier.control1.offset(to: grid.snap(bezier.control1 + offset1))
        guard !snappedOffset0.isZero || !snappedOffset1.isZero else { return }
        events.append(.init(in: pathId, updateEdgeFrom: fromNodeId, .bezier(bezier.with(offset0: snappedOffset0).with(offset1: snappedOffset1))))
    }

    private func collectEvents(to events: inout [PathEvent], _ movePaths: PathAction.MovePaths) {
        let offset = movePaths.offset
        for pathId in movePaths.pathIds {
            events.append(.init(in: pathId, move: offset))
        }
    }

    private func collectEvents(to events: inout [PathEvent], _ deletePaths: PathAction.DeletePaths) {
        for pathId in deletePaths.pathIds {
            events.append(.delete(.init(pathId: pathId)))
        }
    }
}
