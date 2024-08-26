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
    let pathPropertyStore: PathPropertyStore
    let itemStore: ItemStore
    let activeItem: ActiveItemService
    let viewport: ViewportService
    let grid: GridStore
}

// MARK: actions

extension DocumentUpdater {
    func update(path action: PathAction, pending: Bool = false) {
        handle(.path(action), pending: pending)
    }

    func update(pathProperty action: PathPropertyAction, pending: Bool = false) {
        handle(.pathProperty(action), pending: pending)
    }

    func update(item action: ItemAction, pending: Bool = false) {
        handle(.item(action), pending: pending)
    }

    func update(focusedPath kind: PathAction.Update.Kind, pending: Bool = false) {
        guard let pathId = activeItem.focusedPathId else { return }
        handle(.path(.update(.init(pathId: pathId, kind: kind))), pending: pending)
    }

    func groupSelection() {
        let groupId = UUID()
        let members = activeItem.selectedItems.map { $0.id }
        let inGroupId = global.item.commonAncestorId(of: members)
        update(item: .group(.init(groupId: groupId, members: members, inGroupId: inGroupId)))
        activeItem.onTap(itemId: groupId)
    }

    func deleteSelection() {
        let pathIds = activeItem.selectedItems.map { $0.id }
        // TODO: fixme
        global.documentUpdater.update(path: .delete(.init(pathIds: pathIds)))
    }

    func cancel() {
        store.pendingEventSubject.send(nil)
    }
}

// MARK: handle action

private extension DocumentUpdater {
    func handle(_ action: DocumentAction, pending: Bool) {
        let _r = subtracer.range(type: .intent, "handle action, pending: \(pending)"); defer { _r() }
        var events: [DocumentEvent.Single] = []

        switch action {
        case let .path(action): collect(events: &events, of: action)
        case let .pathProperty(action): collect(events: &events, of: action)
        case let .item(action): collect(events: &events, of: action)
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

// MARK: events of path action

private extension DocumentUpdater {
    func collect(events: inout [DocumentEvent.Single], of action: PathAction) {
        switch action {
        case let .load(action): collect(events: &events, of: action)
        case let .create(action): collect(events: &events, of: action)
        case let .delete(action): collect(events: &events, of: action)
        case let .update(action): collect(events: &events, of: action)

        case let .move(action): collect(events: &events, of: action)
        }
    }

    func collect(events: inout [DocumentEvent.Single], of action: PathAction.Load) {
        let symbolId = action.symbolId,
            pathIds = action.pathIds,
            paths = action.paths
        guard pathIds.count == paths.count else { return }
        for i in pathIds.indices {
            let pathId = pathIds[i], path = paths[i]
            events.append(.path(.create(.init(symbolId: symbolId, pathId: pathId, path: path))))
        }
    }

    func collect(events: inout [DocumentEvent.Single], of action: PathAction.Create) {
        let symbolId = action.symbolId,
            pathId = action.pathId,
            path = action.path
        events.append(.path(.create(.init(symbolId: symbolId, pathId: pathId, path: path))))
    }

    func collect(events: inout [DocumentEvent.Single], of action: PathAction.Delete) {
        let pathIds = action.pathIds
        for pathId in pathIds {
            events.append(.path(.delete(.init(pathId: pathId))))
        }
    }

    func collect(events: inout [DocumentEvent.Single], of action: PathAction.Move) {
        let pathIds = action.pathIds,
            offset = action.offset
        for pathId in pathIds {
            events.append(.path(.update(.init(pathId: pathId, kinds: [.move(.init(offset: offset))]))))
        }
    }

    // MARK: single path update actions

    func collect(events: inout [DocumentEvent.Single], of action: PathAction.Update) {
        let pathId = action.pathId
        switch action.kind {
        case let .addEndingNode(action): collect(events: &events, pathId: pathId, of: action)
        case let .splitSegment(action): collect(events: &events, pathId: pathId, of: action)
        case let .deleteNodes(action): collect(events: &events, pathId: pathId, of: action)

        case let .updateNode(action): collect(events: &events, pathId: pathId, of: action)
        case let .updateSegment(action): collect(events: &events, pathId: pathId, of: action)

        case let .moveNodes(action): collect(events: &events, pathId: pathId, of: action)
        case let .moveNodeControl(action): collect(events: &events, pathId: pathId, of: action)

        case let .merge(action): collect(events: &events, pathId: pathId, of: action)
        case let .split(action): collect(events: &events, pathId: pathId, of: action)
        }
    }

    func collect(events: inout [DocumentEvent.Single], pathId: UUID, of action: PathAction.Update.AddEndingNode) {
        let endingNodeId = action.endingNodeId,
            newNodeId = action.newNodeId,
            offset = action.offset
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

    func collect(events: inout [DocumentEvent.Single], pathId: UUID, of action: PathAction.Update.SplitSegment) {
        let fromNodeId = action.fromNodeId,
            paramT = action.paramT,
            newNodeId = action.newNodeId,
            offset = action.offset
        guard let path = pathStore.get(id: pathId),
              let segment = path.segment(fromId: fromNodeId),
              var fromNode = path.node(id: fromNodeId),
              let toNodeId = path.nodeId(after: fromNodeId),
              var toNode = path.node(id: toNodeId) else { return }
        let position = segment.position(paramT: paramT)
        let (before, after) = segment.split(paramT: paramT)
        let snappedOffset = position.offset(to: grid.snap(position + offset))

        let newNode = PathNode(position: position + snappedOffset, cubicIn: before.toCubicIn, cubicOut: after.fromCubicOut)
        fromNode.cubicOut = before.fromCubicOut
        toNode.cubicIn = after.toCubicIn

        events.append(.path(.init(in: pathId, [
            .nodeCreate(.init(prevNodeId: fromNodeId, nodeId: newNodeId, node: newNode)),
            .nodeUpdate(.init(nodeId: fromNodeId, node: fromNode)),
            .nodeUpdate(.init(nodeId: toNodeId, node: toNode)),
        ])))
    }

    func collect(events: inout [DocumentEvent.Single], pathId: UUID, of action: PathAction.Update.DeleteNodes) {
        let nodeIds = action.nodeIds
        guard let path = pathStore.get(id: pathId) else { return }
        if path.nodes.count - nodeIds.count < 2 {
            events.append(.path(.delete(.init(pathId: pathId))))
            return
        }
        for nodeId in nodeIds {
            events.append(.path(.init(in: pathId, .nodeDelete(.init(nodeId: nodeId)))))
        }
    }

    func collect(events: inout [DocumentEvent.Single], pathId: UUID, of action: PathAction.Update.UpdateNode) {
        let nodeId = action.nodeId, node = action.node
        events.append(.path(.init(in: pathId, .nodeUpdate(.init(nodeId: nodeId, node: node)))))
    }

    func collect(events: inout [DocumentEvent.Single], pathId: UUID, of action: PathAction.Update.UpdateSegment) {
        let fromNodeId = action.fromNodeId,
            segment = action.segment
        guard let path = pathStore.get(id: pathId),
              var fromNode = path.node(id: fromNodeId),
              let toNodeId = path.nodeId(after: fromNodeId),
              var toNode = path.node(id: toNodeId) else { return }
        fromNode.position = segment.from
        fromNode.cubicOut = segment.fromCubicOut
        toNode.position = segment.to
        toNode.cubicIn = segment.toCubicIn
        events.append(.path(.init(in: pathId, .nodeUpdate(.init(nodeId: fromNodeId, node: fromNode)))))
        events.append(.path(.init(in: pathId, .nodeUpdate(.init(nodeId: toNodeId, node: toNode)))))
    }

    func collect(events: inout [DocumentEvent.Single], pathId: UUID, of action: PathAction.Update.MoveNodes) {
        let nodeIds = action.nodeIds,
            offset = action.offset
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

    func collect(events: inout [DocumentEvent.Single], pathId: UUID, of action: PathAction.Update.MoveNodeControl) {
        let nodeId = action.nodeId,
            offset = action.offset,
            controlType = action.controlType
        guard let path = pathStore.get(id: pathId),
              let node = path.node(id: nodeId) else { return }

        var snappedCubicInOffset: Vector2 = .zero
        var snappedCubicOutOffset: Vector2 = .zero
        var snappedQuadraticOffset: Vector2 = .zero
        switch controlType {
        case .cubicIn:
            let snappedCubicIn = grid.snap(node.positionIn + offset)
            snappedCubicInOffset = node.positionIn.offset(to: snappedCubicIn)
            guard !snappedCubicInOffset.isZero else { return }
        case .cubicOut:
            let snappedCubicOut = grid.snap(node.positionOut + offset)
            snappedCubicOutOffset = node.positionOut.offset(to: snappedCubicOut)
            guard !snappedCubicOutOffset.isZero else { return }
        case .quadraticOut:
            guard let segment = path.segment(fromId: nodeId),
                  let quadratic = segment.quadratic else { return }
            let snappedQuadratic = grid.snap(quadratic + offset)
            snappedQuadraticOffset = quadratic.offset(to: snappedQuadratic)
            guard !snappedQuadraticOffset.isZero else { return }
        }

        var kinds: [PathEvent.Update.Kind] = []
        defer { events.append(.path(.init(in: pathId, kinds))) }

        guard let property = pathPropertyStore.get(id: pathId) else { return }
        let nodeType = property.nodeType(id: nodeId)
        switch controlType {
        case .cubicIn:
            let newCubicIn = node.cubicIn + snappedCubicInOffset,
                newCubicOut = nodeType.map(current: node.cubicOut, opposite: newCubicIn)
            kinds.append(.nodeUpdate(.init(nodeId: nodeId, node: .init(position: node.position, cubicIn: newCubicIn, cubicOut: newCubicOut))))
        case .cubicOut:
            let newCubicOut = node.cubicOut + snappedCubicOutOffset,
                newCubicIn = nodeType.map(current: node.cubicIn, opposite: newCubicOut)
            kinds.append(.nodeUpdate(.init(nodeId: nodeId, node: .init(position: node.position, cubicIn: newCubicIn, cubicOut: newCubicOut))))
        case .quadraticOut:
            guard let segment = path.segment(fromId: nodeId),
                  let quadratic = segment.quadratic,
                  let nextId = path.nodeId(after: nodeId),
                  let next = path.node(id: nextId) else { return }
            let newQuadratic = quadratic + snappedQuadraticOffset,
                newSegment = PathSegment(from: segment.from, to: segment.to, quadratic: newQuadratic)
            kinds.append(.nodeUpdate(.init(nodeId: nodeId, node: .init(position: node.position, cubicIn: node.cubicIn, cubicOut: newSegment.fromCubicOut))))
            kinds.append(.nodeUpdate(.init(nodeId: nextId, node: .init(position: next.position, cubicIn: newSegment.toCubicIn, cubicOut: next.cubicOut))))
        }
    }

    func collect(events: inout [DocumentEvent.Single], pathId: UUID, of action: PathAction.Update.Merge) {
        let endingNodeId = action.endingNodeId,
            mergedPathId = action.mergedPathId,
            mergedEndingNodeId = action.mergedEndingNodeId
        events.append(.path(.merge(.init(pathId: pathId, endingNodeId: endingNodeId, mergedPathId: mergedPathId, mergedEndingNodeId: mergedEndingNodeId))))
    }

    func collect(events: inout [DocumentEvent.Single], pathId: UUID, of action: PathAction.Update.Split) {
        let nodeId = action.nodeId,
            newNodeId = action.newNodeId,
            newPathId = action.newPathId
        events.append(.path(.split(.init(pathId: pathId, nodeId: nodeId, newPathId: newPathId, newNodeId: newNodeId))))
    }
}

// MARK: events of path property action

private extension DocumentUpdater {
    func collect(events: inout [DocumentEvent.Single], of action: PathPropertyAction) {
        switch action {
        case let .update(action):
            let pathId = action.pathId
            switch action.kind {
            case let .setName(action): collect(events: &events, pathId: pathId, of: action)
            case let .setNodeType(action): collect(events: &events, pathId: pathId, of: action)
            case let .setSegmentType(action): collect(events: &events, pathId: pathId, of: action)
            }
        }
    }

    func collect(events: inout [DocumentEvent.Single], pathId: UUID, of action: PathPropertyAction.Update.SetName) {
        let name = action.name
        events.append(.pathProperty(.update(.init(pathId: pathId, kinds: [.setName(.init(name: name))]))))
    }

    func collect(events: inout [DocumentEvent.Single], pathId: UUID, of action: PathPropertyAction.Update.SetNodeType) {
        let nodeIds = action.nodeIds,
            nodeType = action.nodeType
        events.append(.pathProperty(.update(.init(pathId: pathId, kinds: [.setNodeType(.init(nodeIds: nodeIds, nodeType: nodeType))]))))
    }

    func collect(events: inout [DocumentEvent.Single], pathId: UUID, of action: PathPropertyAction.Update.SetSegmentType) {
        let fromNodeIds = action.fromNodeIds,
            segmentType = action.segmentType
        events.append(.pathProperty(.update(.init(pathId: pathId, kinds: [.setSegmentType(.init(fromNodeIds: fromNodeIds, segmentType: segmentType))]))))
    }
}

// MARK: events of item action

private extension DocumentUpdater {
    func collect(events: inout [DocumentEvent.Single], of action: ItemAction) {
        switch action {
        case let .group(action): collect(events: &events, of: action)
        case let .ungroup(action): collect(events: &events, of: action)
        case let .reorder(action): collect(events: &events, of: action)
        case let .createSymbol(action): collect(events: &events, of: action)
        case let .deleteSymbols(action): collect(events: &events, of: action)
        case let .moveSymbols(action): collect(events: &events, of: action)
        case let .resizeSymbol(action): collect(events: &events, of: action)
        }
    }

    func collect(events: inout [DocumentEvent.Single], of action: ItemAction.Group) {
        let groupId = action.groupId,
            members = action.members,
            inSymbolId = action.inSymbolId,
            inGroupId = action.inGroupId
        guard itemStore.get(id: groupId) == nil else { return } // new group id already exists
        if let inGroupId {
            let ancestors = itemStore.ancestorIds(of: inGroupId)
            guard !ancestors.contains(inGroupId) else { return } // cyclic grouping
        }

        let symbolId: UUID
        if let inGroupId {
            guard let id = itemStore.symbolId(of: inGroupId) else { return } // no symbol found
            symbolId = id
        } else if let inSymbolId {
            symbolId = inSymbolId
        } else {
            return // no grouping target
        }

        for itemId in members {
            guard itemStore.symbolId(of: itemId) == symbolId else { return } // members not in the same symbol
        }

        let groupedMembers = Set(members)
        func hasGrouped(in members: [UUID]) -> Bool { members.contains { groupedMembers.contains($0) } }
        func removeGrouped(from members: inout [UUID]) { members.removeAll { groupedMembers.contains($0) } }

        func adjustRootMembers() {
            guard var symbol = itemStore.symbol(id: symbolId),
                  inSymbolId == symbolId || hasGrouped(in: symbol.members) else { return }
            removeGrouped(from: &symbol.members)
            if inSymbolId == symbolId {
                symbol.members.append(groupId)
            }
            events.append(.item(.setSymbol(symbol.event)))
        }

        func adjustMembers(in group: ItemGroup) {
            var group = group
            guard inGroupId == group.id || hasGrouped(in: members) else { return }
            removeGrouped(from: &group.members)
            if inGroupId == group.id {
                group.members.append(group.id)
            }
            events.append(.item(.setGroup(group.event)))
        }

        adjustRootMembers()
        for group in itemStore.allGroups(symbolId: symbolId) {
            adjustMembers(in: group)
        }

        events.append(.item(.setGroup(.init(groupId: groupId, members: members))))
    }

    func collect(events: inout [DocumentEvent.Single], of action: ItemAction.Ungroup) {
        let groupIds = action.groupIds,
            symbolId = groupIds.compactMap { itemStore.symbolId(of: $0) }.allSame()
        guard let symbolId else { return } // groups not in the same symbol

        let ungroupedGroups = Set(groupIds)
        func hasUngrouped(in members: [UUID]) -> Bool { members.contains { ungroupedGroups.contains($0) } }
        func expandUngrouped(in members: inout [UUID]) {
            members = members.flatMap {
                guard ungroupedGroups.contains($0) else { return [$0] }
                guard let group = itemStore.group(id: $0) else { return [] }
                return group.members
            }
        }

        func adjustRootMembers() {
            guard var symbol = itemStore.symbol(id: symbolId),
                  hasUngrouped(in: symbol.members) else { return }
            expandUngrouped(in: &symbol.members)
            events.append(.item(.setSymbol(symbol.event)))
        }

        func adjustMembers(in group: ItemGroup) {
            var group = group
            guard hasUngrouped(in: group.members) else { return }
            expandUngrouped(in: &group.members)
            events.append(.item(.setGroup(group.event)))
        }

        for groupId in groupIds {
            events.append(.item(.setGroup(.init(groupId: groupId, members: []))))
        }

        adjustRootMembers()
        for group in itemStore.allGroups(symbolId: symbolId) {
            adjustMembers(in: group)
        }
    }

    func collect(events: inout [DocumentEvent.Single], of action: ItemAction.Reorder) {
        let itemId = action.itemId,
            toItemId = action.toItemId,
            isAfter = action.isAfter,
            parentId = itemStore.parentId(of: itemId),
            toParentId = itemStore.parentId(of: toItemId)
        guard let symbolId = itemStore.symbolId(of: itemId),
              let symbol = itemStore.symbol(id: symbolId) else { return } // no symbol found
        guard itemStore.symbolId(of: toItemId) == symbolId else { return } // not in the same symbol
        if parentId == toParentId {
            guard itemId != toItemId else { return } // not moved
            if let parentId, var group = itemStore.group(id: parentId) {
                group.members.removeAll { $0 == itemId }
                let index = group.members.firstIndex(of: toItemId) ?? 0
                group.members.insert(itemId, at: isAfter ? group.members.index(after: index) : index)
                events.append(.item(.setGroup(group.event)))
            } else {
                var symbol = symbol
                symbol.members.removeAll { $0 == itemId }
                let index = symbol.members.firstIndex(of: toItemId) ?? 0
                symbol.members.insert(itemId, at: isAfter ? symbol.members.index(after: index) : index)
                events.append(.item(.setSymbol(symbol.event)))
            }
            return
        }
        guard itemStore.ancestorIds(of: toItemId).firstIndex(of: itemId) == nil else { return } // cyclic moving
        if let parentId, var group = itemStore.group(id: parentId) {
            group.members.removeAll { $0 == itemId }
            events.append(.item(.setGroup(group.event)))
        } else {
            var symbol = symbol
            symbol.members.removeAll { $0 == itemId }
            events.append(.item(.setSymbol(symbol.event)))
        }
        if let toParentId, var toGroup = itemStore.group(id: toParentId) {
            let index = toGroup.members.firstIndex(of: toItemId) ?? 0
            toGroup.members.insert(itemId, at: isAfter ? toGroup.members.index(after: index) : index)
            events.append(.item(.setGroup(toGroup.event)))
        } else {
            var symbol = symbol
            let index = symbol.members.firstIndex(of: toItemId) ?? 0
            symbol.members.insert(itemId, at: isAfter ? symbol.members.index(after: index) : index)
            events.append(.item(.setSymbol(symbol.event)))
        }
    }

    func collect(events: inout [DocumentEvent.Single], of action: ItemAction.CreateSymbol) {
        let symbolId = action.symbolId,
            origin = action.origin,
            size = action.size
        events.append(.item(.setSymbol(.init(symbolId: symbolId, origin: origin, size: size, members: []))))
    }

    func collect(events: inout [DocumentEvent.Single], of action: ItemAction.DeleteSymbols) {
        let symbolIds = action.symbolIds
        for symbolId in symbolIds {
            events.append(.item(.deleteSymbol(.init(symbolId: symbolId))))
        }
    }

    func collect(events: inout [DocumentEvent.Single], of action: ItemAction.MoveSymbols) {
        let symbolIds = action.symbolIds,
            offset = action.offset
        for symbolId in symbolIds {
            guard var symbol = itemStore.symbol(id: symbolId) else { continue }
            symbol.origin += offset
            events.append(.item(.setSymbol(symbol.event)))
        }
    }

    func collect(events: inout [DocumentEvent.Single], of action: ItemAction.ResizeSymbol) {
        let symbolId = action.symbolId,
            origin = action.origin,
            size = action.size
        guard let symbol = itemStore.symbol(id: symbolId) else { return }
        events.append(.item(.setSymbol(.init(symbolId: symbolId, origin: origin, size: size, members: symbol.members))))
    }
}
