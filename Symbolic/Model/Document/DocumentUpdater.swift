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
    let store: DocumentUpdaterStore
    let pathStore: PathStore
    let itemStore: ItemStore
    let pathPropertyStore: PathPropertyStore
    let activeItem: ActiveItemService
    let viewport: ViewportService
    let grid: GridStore
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
            case let .moveNodeControl(kind):
                .moveNodeControl(.init(nodeId: kind.nodeId, controlInOffset: kind.controlInOffset.applying(toWorld), controlOutOffset: kind.controlOutOffset.applying(toWorld)))

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
    private func collectEvents(to events: inout [SingleEvent], _ action: ItemAction) {
        switch action {
        case let .group(action): collectEvents(to: &events, action)
        case let .ungroup(action): collectEvents(to: &events, action)
        case let .reorder(action): collectEvents(to: &events, action)
        }
    }

    private func collectEvents(to events: inout [SingleEvent], _ action: ItemAction.Group) {
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
                events.append(.item(.setMembers(.init(members: newMembers, inGroupId: id))))
            }
        }

        events.append(.item(.setMembers(.init(members: group.members, inGroupId: group.id))))

        moveOut(from: nil)
        for other in allGroups {
            moveOut(from: other)
        }
    }

    private func collectEvents(to events: inout [SingleEvent], _ action: ItemAction.Ungroup) {
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
                events.append(.item(.setMembers(.init(members: newMembers, inGroupId: id))))
            }
        }

        for groupId in groupIds {
            events.append(.item(.setMembers(.init(members: [], inGroupId: groupId))))
        }

        moveIn(to: nil)
        for other in allGroups {
            moveIn(to: other)
        }
    }

    private func collectEvents(to events: inout [SingleEvent], _ action: ItemAction.Reorder) {
        let members = action.members, inGroupId = action.inGroupId
        // TODO: assert something
        events.append(.item(.setMembers(.init(members: members, inGroupId: inGroupId))))
    }
}

// MARK: collect path events

extension DocumentUpdater {
    private func collectEvents(to events: inout [SingleEvent], _ action: PathAction) {
        switch action {
        case let .load(action): collectEvents(to: &events, action)
        case let .create(action): collectEvents(to: &events, action)
        case let .delete(action): collectEvents(to: &events, action)
        case let .update(action): collectEvents(to: &events, action)

        case let .move(action): collectEvents(to: &events, action)
        case let .merge(action): collectEvents(to: &events, action)
        case let .breakAtNode(action): collectEvents(to: &events, action)
        case let .breakAtSegment(action): collectEvents(to: &events, action)
        }
    }

    private func collectEvents(to events: inout [SingleEvent], _ action: PathAction.Load) {
        let paths = action.paths
        events.append(.path(.create(.init(paths: paths))))
    }

    private func collectEvents(to events: inout [SingleEvent], _ action: PathAction.Create) {
        let path = action.path
        events.append(.path(.create(.init(paths: [path]))))
    }

    private func collectEvents(to events: inout [SingleEvent], _ action: PathAction.Delete) {
        let pathIds = action.pathIds
        events.append(.path(.delete(.init(pathIds: pathIds))))
    }

    // MARK: single path update actions

    private func collectEvents(to events: inout [SingleEvent], _ action: PathAction.Update) {
        let pathId = action.pathId
        switch action.kind {
        case let .deleteNodes(action): collectEvents(to: &events, pathId: pathId, action)
        case let .updateNode(action): collectEvents(to: &events, pathId: pathId, action)

        case let .addEndingNode(action): collectEvents(to: &events, pathId: pathId, action)
        case let .splitSegment(action): collectEvents(to: &events, pathId: pathId, action)

        case let .moveNodes(action): collectEvents(to: &events, pathId: pathId, action)
        case let .moveNodeControl(action): collectEvents(to: &events, pathId: pathId, action)
        }
    }

    private func collectEvents(to events: inout [SingleEvent], pathId: UUID, _ action: PathAction.Update.DeleteNodes) {
        let nodeIds = action.nodeIds
        guard let path = pathStore.get(id: pathId) else { return }
        if path.nodes.count - nodeIds.count < 2 {
            events.append(.path(.delete(.init(pathIds: [pathId]))))
            return
        }
        for nodeId in nodeIds {
            events.append(.path(.init(in: pathId, .nodeDelete(.init(nodeId: nodeId)))))
        }
    }

    private func collectEvents(to events: inout [SingleEvent], pathId: UUID, _ action: PathAction.Update.UpdateNode) {
        let nodeId = action.nodeId, node = action.node
        events.append(.path(.init(in: pathId, .nodeUpdate(.init(nodeId: nodeId, node: node)))))
    }

    private func collectEvents(to events: inout [SingleEvent], pathId: UUID, _ action: PathAction.Update.AddEndingNode) {
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
        events.append(.path(.init(in: pathId, .nodeCreate(.init(prevNodeId: prevNodeId, nodeId: newNodeId, node: .init(position: endingNode.position + snappedOffset))))))
    }

    private func collectEvents(to events: inout [SingleEvent], pathId: UUID, _ action: PathAction.Update.SplitSegment) {
        let fromNodeId = action.fromNodeId, paramT = action.paramT, newNodeId = action.newNodeId, offset = action.offset
        guard let path = pathStore.get(id: pathId),
              let segment = path.segment(fromId: fromNodeId),
              var fromNode = path.node(id: fromNodeId),
              let toNodeId = path.nodeId(after: fromNodeId),
              var toNode = path.node(id: toNodeId) else { return }
        let position = segment.position(paramT: paramT)
        let (before, after) = segment.split(paramT: paramT)
        let snappedOffset = position.offset(to: grid.snap(position + offset))

        let newNode = PathNode(position: position + snappedOffset, controlIn: before.toControlIn, controlOut: after.fromControlOut)
        fromNode.controlOut = before.fromControlOut
        toNode.controlIn = after.toControlIn

        events.append(.path(.init(in: pathId, [
            .nodeCreate(.init(prevNodeId: fromNodeId, nodeId: newNodeId, node: newNode)),
            .nodeUpdate(.init(nodeId: fromNodeId, node: fromNode)),
            .nodeUpdate(.init(nodeId: toNodeId, node: toNode)),
        ])))
    }

    private func collectEvents(to events: inout [SingleEvent], pathId: UUID, _ action: PathAction.Update.MoveNodes) {
        let nodeIds = action.nodeIds, offset = action.offset
        guard let path = pathStore.get(id: pathId),
              let firstId = nodeIds.first,
              let firstNode = path.node(id: firstId) else { return }
        let snappedOffset = firstNode.position.offset(to: grid.snap(firstNode.position + offset))
        guard !snappedOffset.isZero else { return }

        var kinds: [PathEvent.Update.Kind] = []
        defer { events.append(.path(.init(in: pathId, kinds))) }

        for nodeId in nodeIds {
            guard var node = path.node(id: nodeId) else { continue }
            node.position += snappedOffset
            kinds.append(.nodeUpdate(.init(nodeId: nodeId, node: node)))
        }
    }

    private func collectEvents(to events: inout [SingleEvent], pathId: UUID, _ action: PathAction.Update.MoveNodeControl) {
        let nodeId = action.nodeId, controlInOffset = action.controlInOffset, controlOutOffset = action.controlOutOffset
        guard let path = pathStore.get(id: pathId),
              let node = path.node(id: nodeId) else { return }

        let snappedControlInOffset: Vector2 = {
            guard controlInOffset != .zero else { return .zero }
            let snappedControlIn = grid.snap(node.positionIn + controlInOffset)
            return node.positionIn.offset(to: snappedControlIn)
        }()
        let snappedControlOutOffset: Vector2 = {
            guard controlOutOffset != .zero else { return .zero }
            let snappedControlOut = grid.snap(node.positionOut + controlOutOffset)
            return node.positionOut.offset(to: snappedControlOut)
        }()

        let draggedIn = !snappedControlInOffset.isZero, draggedOut = !snappedControlOutOffset.isZero
        guard draggedIn || draggedOut else { return }

        var kinds: [PathEvent.Update.Kind] = []
        defer { events.append(.path(.init(in: pathId, kinds))) }

        var newControlIn = node.controlIn + snappedControlInOffset, newControlOut = node.controlOut + snappedControlOutOffset

        guard let property = pathPropertyStore.get(id: pathId) else { return }
        let nodeType = property.nodeType(id: nodeId)
        if draggedIn {
            switch nodeType {
            case .corner: break
            case .locked: newControlOut = newControlIn.with(length: -newControlOut.length)
            case .mirrored: newControlOut = -newControlIn
            }
        } else if draggedOut {
            switch nodeType {
            case .corner: break
            case .locked: newControlIn = newControlOut.with(length: -newControlIn.length)
            case .mirrored: newControlIn = -newControlOut
            }
        }

        kinds.append(.nodeUpdate(.init(nodeId: nodeId, node: .init(position: node.position, controlIn: newControlIn, controlOut: newControlOut))))
    }

    // MARK: multiple path update actions

    private func collectEvents(to events: inout [SingleEvent], _ action: PathAction.Move) {
        let offset = action.offset, pathIds = action.pathIds
        events.append(.path(.move(.init(pathIds: pathIds, offset: offset))))
    }

    private func collectEvents(to events: inout [SingleEvent], _ action: PathAction.Merge) {
        let pathId = action.pathId, endingNodeId = action.endingNodeId, mergedPathId = action.mergedPathId, mergedEndingNodeId = action.mergedEndingNodeId
        events.append(.path(.merge(.init(pathId: pathId, endingNodeId: endingNodeId, mergedPathId: mergedPathId, mergedEndingNodeId: mergedEndingNodeId))))
    }

    private func collectEvents(to events: inout [SingleEvent], _ action: PathAction.BreakAtNode) {
        let pathId = action.pathId, nodeId = action.nodeId, newNodeId = action.newNodeId, newPathId = action.newPathId
        events.append(.path(.nodeBreak(.init(pathId: pathId, nodeId: nodeId, newNodeId: newNodeId, newPathId: newPathId))))
    }

    private func collectEvents(to events: inout [SingleEvent], _ action: PathAction.BreakAtSegment) {
        let pathId = action.pathId, fromNodeId = action.fromNodeId, newPathId = action.newPathId
        events.append(.path(.segmentBreak(.init(pathId: pathId, fromNodeId: fromNodeId, newPathId: newPathId))))
    }
}

// MARK: collect path property events

extension DocumentUpdater {
    private func collectEvents(to events: inout [SingleEvent], _ action: PathPropertyAction) {
        switch action {
        case let .update(action):
            let pathId = action.pathId
            switch action.kind {
            case let .setName(action): collectEvents(to: &events, pathId, action)
            case let .setNodeType(action): collectEvents(to: &events, pathId, action)
            case let .setSegmentType(action): collectEvents(to: &events, pathId, action)
            }
        }
    }

    private func collectEvents(to events: inout [SingleEvent], _ pathId: UUID, _ action: PathPropertyAction.Update.SetName) {
        let name = action.name
        events.append(.pathProperty(.update(.init(pathId: pathId, kinds: [.setName(.init(name: name))]))))
    }

    private func collectEvents(to events: inout [SingleEvent], _ pathId: UUID, _ action: PathPropertyAction.Update.SetNodeType) {
        let nodeIds = action.nodeIds, nodeType = action.nodeType
        events.append(.pathProperty(.update(.init(pathId: pathId, kinds: [.setNodeType(.init(nodeIds: nodeIds, nodeType: nodeType))]))))
    }

    private func collectEvents(to events: inout [SingleEvent], _ pathId: UUID, _ action: PathPropertyAction.Update.SetSegmentType) {
        let fromNodeIds = action.fromNodeIds, segmentType = action.segmentType
        events.append(.pathProperty(.update(.init(pathId: pathId, kinds: [.setSegmentType(.init(fromNodeIds: fromNodeIds, segmentType: segmentType))]))))
    }
}
