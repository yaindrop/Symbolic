import Combine
import Foundation
import SwiftUI

private let subtracer = tracer.tagged("DocumentUpdater")

class DocumentUpdaterStore: Store {
    var eventPublisher: AnyPublisher<DocumentEvent, Never> { eventSubject.eraseToAnyPublisher() }
    var pendingEventPublisher: AnyPublisher<DocumentEvent?, Never> { pendingEventSubject.eraseToAnyPublisher() }

    fileprivate let eventSubject = PassthroughSubject<DocumentEvent, Never>()
    fileprivate let pendingEventSubject = PassthroughSubject<DocumentEvent?, Never>()
}

// MARK: - DocumentUpdater

struct DocumentUpdater {
    let pathStore: PathStore
    let itemStore: ItemStore
    let activeItem: ActiveItemService
    let viewport: ViewportService
    let grid: GridStore
    let store: DocumentUpdaterStore
}

// MARK: update activePath

extension DocumentUpdater {
    func update(activePath kind: PathAction.Single.Kind, pending: Bool = false) {
        guard let activePathId = activeItem.activePath?.id else { return }
        handle(.pathAction(.single(.init(pathId: activePathId, kind: kind))), pending: pending)
    }

    func updateInView(activePath kind: PathAction.Single.Kind, pending: Bool = false) {
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
        update(activePath: kindInWorld, pending: pending)
    }
}

// MARK: update path

extension DocumentUpdater {
    func update(path action: PathAction, pending: Bool = false) {
        handle(.pathAction(action), pending: pending)
    }

    func updateInView(path action: PathAction, pending: Bool = false) {
        var actionInWorld: PathAction {
            switch action {
            case let .move(move):
                .move(.init(pathIds: move.pathIds, offset: move.offset.applying(viewport.toWorld)))
            default: action
            }
        }
        update(path: actionInWorld, pending: pending)
    }
}

// MARK: update selection

extension DocumentUpdater {
    func groupSelection() {
        let groupId = UUID()
        let members = activeItem.selectedItems.map { $0.id }
        let inGroupId = global.item.commonAncestorId(itemIds: members)
        update(item: .group(.init(group: .init(id: groupId, members: members), inGroupId: inGroupId)))
        activeItem.focus(itemId: groupId)
    }

    func deleteSelection() {
        let pathIds = activeItem.selectedItems.map { $0.id }
        // TODO: fixme
        global.documentUpdater.update(path: .delete(.init(pathIds: pathIds)))
    }
}

// MARK: update item

extension DocumentUpdater {
    func update(item action: ItemAction, pending: Bool = false) {
        handle(.itemAction(action), pending: pending)
    }

    func cancel() {
        store.pendingEventSubject.send(nil)
    }
}

// MARK: handle action

extension DocumentUpdater {
    private func handle(_ action: DocumentAction, pending: Bool) {
        let _r = subtracer.range("handle action, pending: \(pending)", type: .intent); defer { _r() }
        var events: [SingleEvent] = []

        switch action {
        case let .itemAction(action): collectEvents(to: &events, action)
        case let .pathAction(action): collectEvents(to: &events, action)
        }

        guard let first = events.first else {
            if pending {
                cancel()
            }
            return
        }

        let event: DocumentEvent
        if events.count == 1 {
            event = .init(kind: .single(first), action: action)
        } else {
            event = .init(kind: .compound(.init(events: events)), action: action)
        }

        if pending {
            let _r = subtracer.range("send pending event \(event)"); defer { _r() }
            store.pendingEventSubject.send(event)
        } else {
            let _r = subtracer.range("send event \(event)"); defer { _r() }
            store.eventSubject.send(event)
        }
    }
}

// MARK: collect item events

extension DocumentUpdater {
    private func collectEvents(to events: inout [SingleEvent], _ action: ItemAction) {
        var itemEvents: [ItemEvent] = []
        switch action {
        case let .group(action): collectEvents(to: &itemEvents, action)
        case let .ungroup(action): collectEvents(to: &itemEvents, action)
        case let .reorder(action): collectEvents(to: &itemEvents, action)
        }
        events += itemEvents.map { .item($0) }
    }

    private func collectEvents(to events: inout [ItemEvent], _ action: ItemAction.Group) {
        let group = action.group, inGroupId = action.inGroupId
        guard itemStore.item(id: group.id) == nil else { return } // grouping with existing id

        if let inGroupId {
            let ancestors = itemStore.ancestorIds(of: inGroupId)
            guard !ancestors.contains(inGroupId) else { return } // cyclic grouping
        }

        let rootIds = itemStore.rootIds, allGroups = itemStore.allGroups, groupedMembers = Set(group.members)

        func moveOut(from other: ItemGroup?) {
            let id = other?.id
            let members = other?.members ?? rootIds
            guard inGroupId == id || members.contains(where: { groupedMembers.contains($0) }) else { return }

            var newMembers = members.filter { !groupedMembers.contains($0) }
            if inGroupId == id {
                newMembers.append(group.id)
            }
            if members != newMembers {
                events.append(.setMembers(.init(members: newMembers, inGroupId: id)))
            }
        }

        events.append(.setMembers(.init(members: group.members, inGroupId: group.id)))

        moveOut(from: nil)
        for other in allGroups {
            moveOut(from: other)
        }
    }

    private func collectEvents(to events: inout [ItemEvent], _ action: ItemAction.Ungroup) {
        let groupIds = action.groupIds
        let rootIds = itemStore.rootIds, allGroups = itemStore.allGroups, ungroupedGroups = Set(groupIds)

        func moveIn(to other: ItemGroup?) {
            let id = other?.id
            let members = other?.members ?? rootIds
            let ungroupedMembers = members.filter { ungroupedGroups.contains($0) }
            guard !ungroupedMembers.isEmpty else { return }

            var newMembers = members.filter { !ungroupedGroups.contains($0) }
            for groupId in ungroupedMembers {
                guard let ungrouped = itemStore.group(id: groupId) else { continue }
                newMembers += ungrouped.members
            }

            if members != newMembers {
                events.append(.setMembers(.init(members: newMembers, inGroupId: id)))
            }
        }

        for groupId in groupIds {
            events.append(.setMembers(.init(members: [], inGroupId: groupId)))
        }

        moveIn(to: nil)
        for other in allGroups {
            moveIn(to: other)
        }
    }

    private func collectEvents(to events: inout [ItemEvent], _ action: ItemAction.Reorder) {
        let members = action.members, inGroupId = action.inGroupId
        // TODO: assert something
        events.append(.setMembers(.init(members: members, inGroupId: inGroupId)))
    }
}

// MARK: collect path events

extension DocumentUpdater {
    private func collectEvents(to events: inout [SingleEvent], _ action: PathAction) {
        var pathEvents: [PathEvent] = []
        switch action {
        case let .load(action): collectEvents(to: &pathEvents, action)
        case let .create(action): collectEvents(to: &pathEvents, action)
        case let .move(action): collectEvents(to: &pathEvents, action)
        case let .delete(action): collectEvents(to: &pathEvents, action)
        case let .single(action): collectEvents(to: &pathEvents, action)
        case let .merge(action): collectEvents(to: &pathEvents, action)
        case let .breakAtNode(action): collectEvents(to: &pathEvents, action)
        case let .breakAtEdge(action): collectEvents(to: &pathEvents, action)
        }
        events += pathEvents.map { .path($0) }
    }

    private func collectEvents(to events: inout [PathEvent], _ action: PathAction.Load) {
        let path = action.path
        events.append(.create(.init(path: path)))
    }

    private func collectEvents(to events: inout [PathEvent], _ action: PathAction.Create) {
        let path = action.path
        events.append(.create(.init(path: path)))
    }

    private func collectEvents(to events: inout [PathEvent], _ action: PathAction.Single) {
        let pathId = action.pathId
        switch action.kind {
        case let .deleteNode(action): collectEvents(to: &events, pathId: pathId, action)
        case let .addEndingNode(action): collectEvents(to: &events, pathId: pathId, action)
        case let .splitSegment(action): collectEvents(to: &events, pathId: pathId, action)

        case let .move(action): collectEvents(to: &events, pathId: pathId, action)
        case let .moveNode(action): collectEvents(to: &events, pathId: pathId, action)
        case let .moveEdge(action): collectEvents(to: &events, pathId: pathId, action)
        case let .moveEdgeControl(action): collectEvents(to: &events, pathId: pathId, action)

        case let .setNodePosition(action): collectEvents(to: &events, pathId: pathId, action)
        case let .setEdge(action): collectEvents(to: &events, pathId: pathId, action)
        }
    }

    private func collectEvents(to events: inout [PathEvent], _ action: PathAction.Move) {
        let offset = action.offset, pathIds = action.pathIds
        for pathId in pathIds {
            events.append(.init(in: pathId, .move(.init(offset: offset))))
        }
    }

    private func collectEvents(to events: inout [PathEvent], _ action: PathAction.Delete) {
        let pathIds = action.pathIds
        for pathId in pathIds {
            events.append(.delete(.init(pathId: pathId)))
        }
    }

    // MARK: single path actions

    private func collectEvents(to events: inout [PathEvent], pathId: UUID, _ action: PathAction.Single.DeleteNode) {
        let nodeId = action.nodeId
        guard let path = pathStore.path(id: pathId),
              path.node(id: nodeId) != nil else { return }
        if path.nodes.count - 1 < 2 {
            events.append(.delete(.init(pathId: pathId)))
        } else {
            events.append(.init(in: pathId, .nodeDelete(.init(nodeId: nodeId))))
        }
    }

    private func collectEvents(to events: inout [PathEvent], pathId: UUID, _ action: PathAction.Single.AddEndingNode) {
        let endingNodeId = action.endingNodeId, newNodeId = action.newNodeId, offset = action.offset
        guard let path = pathStore.path(id: pathId),
              let endingNode = path.node(id: endingNodeId) else { return }
        let prevNodeId: UUID?
        if path.isFirstEndingNode(id: endingNodeId) {
            prevNodeId = nil
        } else if path.isLastEndingNode(id: endingNodeId) {
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
        guard let path = pathStore.path(id: pathId),
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
        guard let path = pathStore.path(id: pathId) else { return }

        let position = path.boundingRect.minPoint
        let snappedOffset = position.offset(to: grid.snap(position + offset))
        guard !snappedOffset.isZero else { return }

        events.append(.init(in: pathId, .move(.init(offset: snappedOffset))))
    }

    private func collectEvents(to events: inout [PathEvent], pathId: UUID, _ action: PathAction.Single.MoveNode) {
        let nodeId = action.nodeId, offset = action.offset
        guard let path = pathStore.path(id: pathId),
              let curr = path.pair(id: nodeId) else { return }
        let snappedOffset = curr.node.position.offset(to: grid.snap(curr.node.position + offset))
        guard !snappedOffset.isZero else { return }

        events.append(.init(in: pathId, .nodeUpdate(.init(node: curr.node.with(offset: snappedOffset)))))
    }

    private func collectEvents(to events: inout [PathEvent], pathId: UUID, _ action: PathAction.Single.MoveEdge) {
        let fromNodeId = action.fromNodeId, offset = action.offset
        guard let path = pathStore.path(id: pathId),
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
        guard let path = pathStore.path(id: pathId),
              let curr = path.segment(from: fromNodeId) else { return }

        let snappedOffset0 = offset0 == .zero ? .zero : curr.control0.offset(to: grid.snap(curr.control0 + offset0))
        let snappedOffset1 = offset1 == .zero ? .zero : curr.control1.offset(to: grid.snap(curr.control1 + offset1))
        guard !snappedOffset0.isZero || !snappedOffset1.isZero else { return }

        let edge = curr.edge
        events.append(.init(in: pathId, .edgeUpdate(.init(fromNodeId: fromNodeId, edge: .init(control0: edge.control0 + snappedOffset0, control1: edge.control1 + snappedOffset1)))))
    }

    private func collectEvents(to events: inout [PathEvent], pathId: UUID, _ action: PathAction.Single.SetNodePosition) {
        let nodeId = action.nodeId, position = action.position
        guard let path = pathStore.path(id: pathId),
              let node = path.node(id: nodeId) else { return }
        events.append(.init(in: pathId, .nodeUpdate(.init(node: node.with(position: position)))))
    }

    private func collectEvents(to events: inout [PathEvent], pathId: UUID, _ action: PathAction.Single.SetEdge) {
        let fromNodeId = action.fromNodeId, edge = action.edge
        events.append(.init(in: pathId, .edgeUpdate(.init(fromNodeId: fromNodeId, edge: edge))))
    }

    private func collectEvents(to events: inout [PathEvent], _ action: PathAction.Merge) {
        let pathId = action.pathId, endingNodeId = action.endingNodeId, mergedPathId = action.mergedPathId, mergedEndingNodeId = action.mergedEndingNodeId
        events.append(.compound(.merge(.init(pathId: pathId, endingNodeId: endingNodeId, mergedPathId: mergedPathId, mergedEndingNodeId: mergedEndingNodeId))))
    }

    private func collectEvents(to events: inout [PathEvent], _ action: PathAction.BreakAtNode) {
        let pathId = action.pathId, nodeId = action.nodeId, newNodeId = action.newNodeId, newPathId = action.newPathId
        events.append(.compound(.nodeBreak(.init(pathId: pathId, nodeId: nodeId, newNodeId: newNodeId, newPathId: newPathId))))
    }

    private func collectEvents(to events: inout [PathEvent], _ action: PathAction.BreakAtEdge) {
        let pathId = action.pathId, fromNodeId = action.fromNodeId, newPathId = action.newPathId
        events.append(.compound(.edgeBreak(.init(pathId: pathId, fromNodeId: fromNodeId, newPathId: newPathId))))
    }
}
