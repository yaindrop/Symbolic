import Combine
import SwiftUI

private let subtracer = tracer.tagged("DocumentUpdater")

class DocumentUpdaterStore: Store {
    fileprivate let eventSubject = PassthroughSubject<DocumentEvent, Never>()
    fileprivate let pendingEventSubject = PassthroughSubject<DocumentEvent?, Never>()
}

extension DocumentUpdaterStore {
    var eventPublisher: AnyPublisher<DocumentEvent, Never> { eventSubject.eraseToAnyPublisher() }
    var pendingEventPublisher: AnyPublisher<DocumentEvent?, Never> { pendingEventSubject.eraseToAnyPublisher() }
}

// MARK: - DocumentUpdater

struct DocumentUpdater {
    let pathStore: PathStore
    let itemStore: ItemStore
    let pathPropertyStore: PathPropertyStore
    let activeItem: ActiveItemService
    let viewport: ViewportService
    let grid: GridStore
    let store: DocumentUpdaterStore
}

// MARK: update focusedPath

extension DocumentUpdater {
    func update(focusedPath kind: PathAction.Update.Kind, pending: Bool = false) {
        guard let pathId = activeItem.focusedPath?.id else { return }
        handle(.path(.update(.init(pathId: pathId, kind: kind))), pending: pending)
    }

    func updateInView(focusedPath kind: PathAction.Update.Kind, pending: Bool = false) {
        let toWorld = viewport.toWorld
        var kindInWorld: PathAction.Update.Kind {
            switch kind {
            case let .addEndingNode(kind):
                .addEndingNode(.init(endingNodeId: kind.endingNodeId, newNodeId: kind.newNodeId, offset: kind.offset.applying(toWorld)))
            case let .splitSegment(kind):
                .splitSegment(.init(fromNodeId: kind.fromNodeId, paramT: kind.paramT, newNodeId: kind.newNodeId, offset: kind.offset.applying(toWorld)))

            case let .moveNodes(kind):
                .moveNodes(.init(nodeIds: kind.nodeIds, offset: kind.offset.applying(toWorld)))
            case let .moveEdgeControl(kind):
                .moveEdgeControl(.init(fromNodeId: kind.fromNodeId, offset0: kind.offset0.applying(toWorld), offset1: kind.offset1.applying(toWorld)))

            default: kind
            }
        }
        update(focusedPath: kindInWorld, pending: pending)
    }
}

// MARK: update path

extension DocumentUpdater {
    func update(path action: PathAction, pending: Bool = false) {
        handle(.path(action), pending: pending)
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
        handle(.item(action), pending: pending)
    }

    func cancel() {
        store.pendingEventSubject.send(nil)
    }
}

// MARK: update path property

extension DocumentUpdater {
    func update(pathProperty action: PathPropertyAction, pending: Bool = false) {
        handle(.pathProperty(action), pending: pending)
    }
}

// MARK: handle action

extension DocumentUpdater {
    private func handle(_ action: DocumentAction, pending: Bool) {
        let _r = subtracer.range(type: .intent, "handle action, pending: \(pending)"); defer { _r() }
        var events: [SingleEvent] = []

        switch action {
        case let .item(action): collectEvents(to: &events, action)
        case let .path(action): collectEvents(to: &events, action)
        case let .pathProperty(action): collectEvents(to: &events, action)
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
    private func collectEvents(to singleEvents: inout [SingleEvent], _ action: ItemAction) {
        var events: [ItemEvent] = []
        switch action {
        case let .group(action): collectEvents(to: &events, action)
        case let .ungroup(action): collectEvents(to: &events, action)
        case let .reorder(action): collectEvents(to: &events, action)
        }
        singleEvents += events.map { .item($0) }
    }

    private func collectEvents(to events: inout [ItemEvent], _ action: ItemAction.Group) {
        let group = action.group, inGroupId = action.inGroupId
        guard itemStore.get(id: group.id) == nil else { return } // grouping with existing id

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
    private func collectEvents(to singleEvents: inout [SingleEvent], _ action: PathAction) {
        var events: [PathEvent] = []
        switch action {
        case let .load(action): collectEvents(to: &events, action)
        case let .create(action): collectEvents(to: &events, action)
        case let .delete(action): collectEvents(to: &events, action)
        case let .update(action): collectEvents(to: &events, action)

        case let .move(action): collectEvents(to: &events, action)
        case let .merge(action): collectEvents(to: &events, action)
        case let .breakAtNode(action): collectEvents(to: &events, action)
        case let .breakAtEdge(action): collectEvents(to: &events, action)
        }
        singleEvents += events.map { .path($0) }
    }

    private func collectEvents(to events: inout [PathEvent], _ action: PathAction.Load) {
        let paths = action.paths
        events.append(.create(.init(paths: paths)))
    }

    private func collectEvents(to events: inout [PathEvent], _ action: PathAction.Create) {
        let path = action.path
        events.append(.create(.init(paths: [path])))
    }

    private func collectEvents(to events: inout [PathEvent], _ action: PathAction.Delete) {
        let pathIds = action.pathIds
        events.append(.delete(.init(pathIds: pathIds)))
    }

    // MARK: single path update actions

    private func collectEvents(to events: inout [PathEvent], _ action: PathAction.Update) {
        let pathId = action.pathId
        switch action.kind {
        case let .deleteNode(action): collectEvents(to: &events, pathId: pathId, action)
        case let .addEndingNode(action): collectEvents(to: &events, pathId: pathId, action)
        case let .splitSegment(action): collectEvents(to: &events, pathId: pathId, action)

        case let .moveNodes(action): collectEvents(to: &events, pathId: pathId, action)
        case let .moveEdgeControl(action): collectEvents(to: &events, pathId: pathId, action)

        case let .setNodePosition(action): collectEvents(to: &events, pathId: pathId, action)
        case let .setEdge(action): collectEvents(to: &events, pathId: pathId, action)
        }
    }

    private func collectEvents(to events: inout [PathEvent], pathId: UUID, _ action: PathAction.Update.DeleteNode) {
        let nodeId = action.nodeId
        guard let path = pathStore.get(id: pathId),
              path.node(id: nodeId) != nil else { return }
        if path.nodes.count - 1 < 2 {
            events.append(.delete(.init(pathIds: [pathId])))
        } else {
            events.append(.init(in: pathId, .nodeDelete(.init(nodeId: nodeId))))
        }
    }

    private func collectEvents(to events: inout [PathEvent], pathId: UUID, _ action: PathAction.Update.AddEndingNode) {
        let endingNodeId = action.endingNodeId, newNodeId = action.newNodeId, offset = action.offset
        guard let path = pathStore.get(id: pathId),
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

    private func collectEvents(to events: inout [PathEvent], pathId: UUID, _ action: PathAction.Update.SplitSegment) {
        let fromNodeId = action.fromNodeId, paramT = action.paramT, newNodeId = action.newNodeId, offset = action.offset
        guard let path = pathStore.get(id: pathId),
              let segment = path.segment(from: fromNodeId) else { return }
        let position = segment.position(paramT: paramT)
        let (before, after) = segment.split(paramT: paramT)
        let snappedOffset = position.offset(to: grid.snap(position + offset))

        events.append(.init(in: pathId, [
            .nodeCreate(.init(prevNodeId: fromNodeId, node: .init(id: newNodeId, position: position + snappedOffset))),
            .edgeUpdate(.init(fromNodeId: fromNodeId, edge: before.edge)),
            .edgeUpdate(.init(fromNodeId: newNodeId, edge: after.edge)),
        ]))
    }

    private func collectEvents(to events: inout [PathEvent], pathId: UUID, _ action: PathAction.Update.MoveNodes) {
        let nodeIds = action.nodeIds, offset = action.offset
        guard let path = pathStore.get(id: pathId),
              let firstId = nodeIds.first,
              let curr = path.pair(id: firstId) else { return }
        let snappedOffset = curr.node.position.offset(to: grid.snap(curr.node.position + offset))
        guard !snappedOffset.isZero else { return }

        var kinds: [PathEvent.Update.Kind] = []
        defer { events.append(.init(in: pathId, kinds)) }

        for nodeId in nodeIds {
            guard let node = path.pair(id: nodeId) else { continue }
            kinds.append(.nodeUpdate(.init(node: node.node.with(offset: snappedOffset))))
        }
    }

    private func collectEvents(to events: inout [PathEvent], pathId: UUID, _ action: PathAction.Update.MoveEdgeControl) {
        let fromNodeId = action.fromNodeId, offset0 = action.offset0, offset1 = action.offset1
        guard let path = pathStore.get(id: pathId),
              let curr = path.segment(from: fromNodeId) else { return }

        let snappedOffset0 = offset0 == .zero ? .zero : curr.control0.offset(to: grid.snap(curr.control0 + offset0))
        let snappedOffset1 = offset1 == .zero ? .zero : curr.control1.offset(to: grid.snap(curr.control1 + offset1))

        let dragged0 = !snappedOffset0.isZero, dragged1 = !snappedOffset1.isZero
        print("dbg", dragged0, dragged1)
        guard dragged0 || dragged1 else { return }

        var kinds: [PathEvent.Update.Kind] = []
        defer {
            print("dbg kinds", kinds)
            events.append(.init(in: pathId, kinds))
        }

        let newControl0 = curr.edge.control0 + snappedOffset0, newControl1 = curr.edge.control1 + snappedOffset1
        kinds.append(.edgeUpdate(.init(fromNodeId: fromNodeId, edge: .init(control0: newControl0, control1: newControl1))))

        guard let property = pathPropertyStore.get(id: pathId) else { return }
        if dragged0 {
            guard let prevNode = path.node(before: fromNodeId),
                  let prev = path.segment(from: prevNode.id),
                  !prev.edge.control1.isZero else { return }
            let nodeType = property.nodeType(id: fromNodeId)
            var newPrevControl1: Vector2? {
                switch nodeType {
                case .corner: nil
                case .locked: newControl0.with(length: -prev.edge.control1.length)
                case .mirrored: -newControl0
                }
            }
            if let newPrevControl1 {
                kinds.append(.edgeUpdate(.init(fromNodeId: prevNode.id, edge: prev.edge.with(control1: newPrevControl1))))
            }
        } else if dragged1 {
            guard let nextNode = path.node(after: fromNodeId),
                  let next = path.segment(from: nextNode.id),
                  !next.edge.control0.isZero else { return }
            let nodeType = property.nodeType(id: nextNode.id)
            var newNextControl0: Vector2? {
                switch nodeType {
                case .corner: nil
                case .locked: newControl1.with(length: -next.edge.control0.length)
                case .mirrored: -newControl1
                }
            }
            if let newNextControl0 {
                kinds.append(.edgeUpdate(.init(fromNodeId: nextNode.id, edge: next.edge.with(control0: newNextControl0))))
            }
        }
    }

    private func collectEvents(to events: inout [PathEvent], pathId: UUID, _ action: PathAction.Update.SetNodePosition) {
        let nodeId = action.nodeId, position = action.position
        guard let path = pathStore.get(id: pathId),
              let node = path.node(id: nodeId) else { return }
        events.append(.init(in: pathId, .nodeUpdate(.init(node: node.with(position: position)))))
    }

    private func collectEvents(to events: inout [PathEvent], pathId: UUID, _ action: PathAction.Update.SetEdge) {
        let fromNodeId = action.fromNodeId, edge = action.edge
        events.append(.init(in: pathId, .edgeUpdate(.init(fromNodeId: fromNodeId, edge: edge))))
    }

    // MARK: multiple path update actions

    private func collectEvents(to events: inout [PathEvent], _ action: PathAction.Move) {
        let offset = action.offset, pathIds = action.pathIds
        events.append(.move(.init(pathIds: pathIds, offset: offset)))
    }

    private func collectEvents(to events: inout [PathEvent], _ action: PathAction.Merge) {
        let pathId = action.pathId, endingNodeId = action.endingNodeId, mergedPathId = action.mergedPathId, mergedEndingNodeId = action.mergedEndingNodeId
        events.append(.merge(.init(pathId: pathId, endingNodeId: endingNodeId, mergedPathId: mergedPathId, mergedEndingNodeId: mergedEndingNodeId)))
    }

    private func collectEvents(to events: inout [PathEvent], _ action: PathAction.BreakAtNode) {
        let pathId = action.pathId, nodeId = action.nodeId, newNodeId = action.newNodeId, newPathId = action.newPathId
        events.append(.nodeBreak(.init(pathId: pathId, nodeId: nodeId, newNodeId: newNodeId, newPathId: newPathId)))
    }

    private func collectEvents(to events: inout [PathEvent], _ action: PathAction.BreakAtEdge) {
        let pathId = action.pathId, fromNodeId = action.fromNodeId, newPathId = action.newPathId
        events.append(.edgeBreak(.init(pathId: pathId, fromNodeId: fromNodeId, newPathId: newPathId)))
    }
}

// MARK: collect path property events

extension DocumentUpdater {
    private func collectEvents(to singleEvents: inout [SingleEvent], _ action: PathPropertyAction) {
        var events: [PathPropertyEvent] = []
        switch action {
        case let .update(action):
            let pathId = action.pathId
            switch action.kind {
            case let .setName(action): collectEvents(to: &events, pathId, action)
            case let .setNodeType(action): collectEvents(to: &events, pathId, action)
            case let .setEdgeType(action): collectEvents(to: &events, pathId, action)
            }
        }
        singleEvents += events.map { .pathProperty($0) }
    }

    private func collectEvents(to events: inout [PathPropertyEvent], _ pathId: UUID, _ action: PathPropertyAction.Update.SetName) {
        let name = action.name
        events.append(.update(.init(pathId: pathId, kinds: [.setName(.init(name: name))])))
    }

    private func collectEvents(to events: inout [PathPropertyEvent], _ pathId: UUID, _ action: PathPropertyAction.Update.SetNodeType) {
        let nodeIds = action.nodeIds, nodeType = action.nodeType
        events.append(.update(.init(pathId: pathId, kinds: [.setNodeType(.init(nodeIds: nodeIds, nodeType: nodeType))])))
    }

    private func collectEvents(to events: inout [PathPropertyEvent], _ pathId: UUID, _ action: PathPropertyAction.Update.SetEdgeType) {
        let fromNodeIds = action.fromNodeIds, edgeType = action.edgeType
        events.append(.update(.init(pathId: pathId, kinds: [.setEdgeType(.init(fromNodeIds: fromNodeIds, edgeType: edgeType))])))
    }
}
