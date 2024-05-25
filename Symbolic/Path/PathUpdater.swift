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
    let activePath: ActivePathService
    let viewport: ViewportService
    let grid: CanvasGridStore
    let store: PathUpdateStore

    func onEvent(_ callback: @escaping (DocumentEvent) -> Void) {
        store.eventSubject.sink(receiveValue: callback).store(in: &store.subscriptions)
    }

    func onPendingEvent(_ callback: @escaping (DocumentEvent?) -> Void) {
        store.pendingEventSubject.sink(receiveValue: callback).store(in: &store.subscriptions)
    }

    // MARK: updateActivePath

    func updateActivePath(_ kind: PathAction.Single.Kind, pending: Bool = false) {
        guard let activePath = activePath.activePath else { return }
        handle(.pathAction(.single(.init(pathId: activePath.id, kind: kind))), pending: pending)
    }

    func updateActivePathInView(_ kind: PathAction.Single.Kind, pending: Bool = false) {
        let toWorld = viewport.toWorld
        var kindInWorld: PathAction.Single.Kind {
            switch kind {
            case let .addEndingNode(kind):
                .addEndingNode(.init(endingNodeId: kind.endingNodeId, newNodeId: kind.newNodeId, offset: kind.offset.applying(toWorld)))
            case let .splitSegment(kind):
                .splitSegment(.init(fromNodeId: kind.fromNodeId, paramT: kind.paramT, newNodeId: kind.newNodeId, offset: kind.offset.applying(toWorld)))

            case let .move(kind):
                .move(.init(offset: kind.offset.applying(toWorld)))
            case let .moveNode(kind):
                .moveNode(.init(nodeId: kind.nodeId, offset: kind.offset.applying(toWorld)))
            case let .moveEdge(kind):
                .moveEdge(.init(fromNodeId: kind.fromNodeId, offset: kind.offset.applying(toWorld)))
            case let .moveEdgeControl(kind):
                .moveEdgeControl(.init(fromNodeId: kind.fromNodeId, offset0: kind.offset0.applying(toWorld), offset1: kind.offset1.applying(toWorld)))

            default: kind
            }
        }
        updateActivePath(kindInWorld, pending: pending)
    }

    // MARK: update

    func update(_ action: PathAction, pending: Bool = false) {
        handle(action, pending: pending)
    }

    func updateInView(_ action: PathAction, pending: Bool = false) {
        var actionInWorld: PathAction {
            switch action {
            case let .movePaths(movePaths):
                .movePaths(.init(pathIds: movePaths.pathIds, offset: movePaths.offset.applying(viewport.toWorld)))
            default: action
            }
        }
        update(actionInWorld)
    }
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
            case let .deleteNode(action): collectEvents(to: &events, pathId: single.pathId, action)
            case let .breakAtNode(action): collectEvents(to: &events, pathId: single.pathId, action)
            case let .breakAtEdge(action): collectEvents(to: &events, pathId: single.pathId, action)

            case let .addEndingNode(action): collectEvents(to: &events, pathId: single.pathId, action)
            case let .splitSegment(action): collectEvents(to: &events, pathId: single.pathId, action)

            case let .move(action): collectEvents(to: &events, pathId: single.pathId, action)
            case let .moveNode(action): collectEvents(to: &events, pathId: single.pathId, action)
            case let .moveEdge(action): collectEvents(to: &events, pathId: single.pathId, action)
            case let .moveEdgeControl(action): collectEvents(to: &events, pathId: single.pathId, action)

            case let .setNodePosition(action): collectEvents(to: &events, pathId: single.pathId, action)
            case let .setEdge(action): collectEvents(to: &events, pathId: single.pathId, action)
            }
        case let .movePaths(movePaths): collectEvents(to: &events, movePaths)
        case let .deletePaths(deletePaths): collectEvents(to: &events, deletePaths)
        }
    }

    // MARK: single path actions

    private func collectEvents(to events: inout [PathEvent], pathId: UUID, _ action: PathAction.Single.DeleteNode) {
        let nodeId = action.nodeId
        events.append(.init(in: pathId, .nodeDelete(.init(nodeId: nodeId))))
    }

    private func collectEvents(to events: inout [PathEvent], pathId: UUID, _ action: PathAction.Single.BreakAtNode) {
        let nodeId = action.nodeId, newNodeId = action.newNodeId, newPathId = action.newPathId
        events.append(.init(in: pathId, .nodeBreak(.init(nodeId: nodeId, newNodeId: newNodeId, newPathId: newPathId))))
    }

    private func collectEvents(to events: inout [PathEvent], pathId: UUID, _ action: PathAction.Single.BreakAtEdge) {
        let fromNodeId = action.fromNodeId, newPathId = action.newPathId
        events.append(.init(in: pathId, .edgeBreak(.init(fromNodeId: fromNodeId, newPathId: newPathId))))
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
        events.append(.init(in: pathId, .nodeCreate(.init(prevNodeId: prevNodeId, node: .init(id: newNodeId, position: endingNode.position + snappedOffset)))))
    }

    private func collectEvents(to events: inout [PathEvent], pathId: UUID, _ action: PathAction.Single.SplitSegment) {
        let fromNodeId = action.fromNodeId, paramT = action.paramT, newNodeId = action.newNodeId, offset = action.offset
        guard let path = pathStore.pathMap.getValue(key: pathId),
              let segment = path.segment(from: fromNodeId) else { return }
        let position = segment.position(paramT: paramT)
        let (before, after) = segment.split(paramT: paramT)
        let snappedOffset = position.offset(to: grid.snap(position + offset))

        events.append(.init(in: pathId, .nodeCreate(.init(prevNodeId: fromNodeId, node: .init(id: newNodeId, position: position + snappedOffset)))))
        events.append(.init(in: pathId, .edgeUpdate(.init(fromNodeId: fromNodeId, edge: before.edge))))
        events.append(.init(in: pathId, .edgeUpdate(.init(fromNodeId: newNodeId, edge: after.edge))))
    }

    // MARK: handle actions

    private func collectEvents(to events: inout [PathEvent], pathId: UUID, _ action: PathAction.Single.Move) {
        let offset = action.offset
        guard let path = pathStore.pathMap.getValue(key: pathId) else { return }

        let position = path.boundingRect.minPoint
        let snappedOffset = position.offset(to: grid.snap(position + offset))
        guard !snappedOffset.isZero else { return }

        events.append(.init(in: pathId, .move(.init(offset: snappedOffset))))
    }

    private func collectEvents(to events: inout [PathEvent], pathId: UUID, _ action: PathAction.Single.MoveNode) {
        let nodeId = action.nodeId, offset = action.offset
        guard let path = pathStore.pathMap.getValue(key: pathId),
              let curr = path.pair(id: nodeId) else { return }
        let snappedOffset = curr.node.position.offset(to: grid.snap(curr.node.position + offset))
        guard !snappedOffset.isZero else { return }

        events.append(.init(in: pathId, .nodeUpdate(.init(node: curr.node.with(offset: snappedOffset)))))
    }

    private func collectEvents(to events: inout [PathEvent], pathId: UUID, _ action: PathAction.Single.MoveEdge) {
        let fromNodeId = action.fromNodeId, offset = action.offset
        guard let path = pathStore.pathMap.getValue(key: pathId),
              let curr = path.pair(id: fromNodeId) else { return }
        let snappedOffset = curr.node.position.offset(to: grid.snap(curr.node.position + offset))
        guard !snappedOffset.isZero else { return }

        events.append(.init(in: pathId, .nodeUpdate(.init(node: curr.node.with(offset: snappedOffset)))))
        if let next = path.pair(after: fromNodeId) {
            events.append(.init(in: pathId, .nodeUpdate(.init(node: next.node.with(offset: snappedOffset)))))
        }
    }

    private func collectEvents(to events: inout [PathEvent], pathId: UUID, _ action: PathAction.Single.MoveEdgeControl) {
        let fromNodeId = action.fromNodeId, offset0 = action.offset0, offset1 = action.offset1
        guard let path = pathStore.pathMap.getValue(key: pathId),
              let curr = path.segment(from: fromNodeId) else { return }

        let snappedOffset0 = offset0 == .zero ? .zero : curr.control0.offset(to: grid.snap(curr.control0 + offset0))
        let snappedOffset1 = offset1 == .zero ? .zero : curr.control1.offset(to: grid.snap(curr.control1 + offset1))
        guard !snappedOffset0.isZero || !snappedOffset1.isZero else { return }

        let edge = curr.edge
        events.append(.init(in: pathId, .edgeUpdate(.init(fromNodeId: fromNodeId, edge: .init(control0: edge.control0 + snappedOffset0, control1: edge.control1 + snappedOffset1)))))
    }

    private func collectEvents(to events: inout [PathEvent], pathId: UUID, _ action: PathAction.Single.SetNodePosition) {
        let nodeId = action.nodeId, position = action.position
        guard let node = pathStore.pathMap.getValue(key: pathId)?.node(id: nodeId) else { return }
        events.append(.init(in: pathId, .nodeUpdate(.init(node: node.with(position: position)))))
    }

    private func collectEvents(to events: inout [PathEvent], pathId: UUID, _ action: PathAction.Single.SetEdge) {
        let fromNodeId = action.fromNodeId, edge = action.edge
        events.append(.init(in: pathId, .edgeUpdate(.init(fromNodeId: fromNodeId, edge: edge))))
    }

    private func collectEvents(to events: inout [PathEvent], _ movePaths: PathAction.MovePaths) {
        let offset = movePaths.offset
        for pathId in movePaths.pathIds {
            events.append(.init(in: pathId, .move(.init(offset: offset))))
        }
    }

    private func collectEvents(to events: inout [PathEvent], _ deletePaths: PathAction.DeletePaths) {
        for pathId in deletePaths.pathIds {
            events.append(.delete(.init(pathId: pathId)))
        }
    }
}
