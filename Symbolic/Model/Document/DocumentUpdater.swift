import Combine
import SwiftUI

private let subtracer = tracer.tagged("DocumentUpdater")

class DocumentUpdaterStore: Store {
    @Passthrough<DocumentEvent> var event
    @Passthrough<DocumentEvent?> var pendingEvent
}

// MARK: - DocumentUpdater

struct DocumentUpdater {
    let store: DocumentUpdaterStore
    let pathStore: PathStore
    let symbolStore: SymbolStore
    let itemStore: ItemStore
    let worldStore: WorldStore
    let activeItem: ActiveItemService
    let viewport: ViewportService
    let grid: GridService
}

// MARK: actions

extension DocumentUpdater {
    func update(path action: PathAction, pending: Bool = false) {
        handle(.path(action), pending: pending)
    }

    func update(symbol action: SymbolAction, pending: Bool = false) {
        handle(.symbol(action), pending: pending)
    }

    func update(item action: ItemAction, pending: Bool = false) {
        handle(.item(action), pending: pending)
    }

    func update(world action: WorldAction, pending: Bool = false) {
        handle(.world(action), pending: pending)
    }

    func update(focusedPath kind: PathAction.Update.Kind, pending: Bool = false) {
        guard let pathId = activeItem.focusedPathId else { return }
        handle(.path(.update(.init(pathId: pathId, kind: kind))), pending: pending)
    }

    func cancel() {
        store.pendingEvent.send(nil)
    }
}

// MARK: handle action

private extension DocumentUpdater {
    func makeEvent(action: DocumentAction) -> DocumentEvent? {
        var events: [DocumentEvent.Single] = []

        switch action {
        case let .path(action): collect(events: &events, of: action)
        case let .symbol(action): collect(events: &events, of: action)
        case let .item(action): collect(events: &events, of: action)
        case let .world(action): collect(events: &events, of: action)
        }

        guard let first = events.first else { return nil }
        if events.count == 1 {
            return .init(kind: .single(first), action: action)
        } else {
            return .init(kind: .compound(.init(events: events)), action: action)
        }
    }

    func handle(_ action: DocumentAction, pending: Bool) {
        let _r = subtracer.range(type: .intent, "handle action, pending: \(pending)"); defer { _r() }
        guard let event = makeEvent(action: action) else {
            let _r = subtracer.range("cancelled"); defer { _r() }
            if pending {
                cancel()
            }
            return
        }

        if pending {
            let _r = subtracer.range("send pending event \(event)"); defer { _r() }
            store.pendingEvent.send(event)
        } else {
            let _r = subtracer.range("send event \(event)"); defer { _r() }
            store.event.send(event)
        }
    }
}

// MARK: events of path action

private extension DocumentUpdater {
    func collect(events: inout [DocumentEvent.Single], of action: PathAction) {
        switch action {
        case let .create(action): collect(events: &events, of: action)
        case let .update(action): collect(events: &events, of: action)

        case let .delete(action): collect(events: &events, of: action)
        case let .move(action): collect(events: &events, of: action)
        }
    }

    func collect(events: inout [DocumentEvent.Single], of action: PathAction.Create) {
        let symbolId = action.symbolId,
            pathId = action.pathId,
            path = action.path
        guard let symbol = itemStore.symbol(id: symbolId) else { return }
        events.append(.path(.init(pathId: pathId, .create(.init(path: path)))))
        let members = symbol.members + [pathId]
        events.append(.symbol(.init(symbolId: symbol.id, .setMembers(.init(members: members)))))
    }

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

        case let .setNodeType(action): collect(events: &events, pathId: pathId, of: action)
        case let .setSegmentType(action): collect(events: &events, pathId: pathId, of: action)
        }
    }

    func collect(events: inout [DocumentEvent.Single], of action: PathAction.Delete) {
        let pathIds = action.pathIds
        events.append(.path(.init(pathIds: pathIds, .delete(.init()))))
    }

    func collect(events: inout [DocumentEvent.Single], of action: PathAction.Move) {
        let pathIds = action.pathIds,
            offset = action.offset,
            paths = pathIds.compactMap { pathStore.get(id: $0) }
        guard !paths.isEmpty else { return }
        let anchor = paths.reduce(into: paths.first!.boundingRect.minPoint) { anchor, path in
            let rect = path.boundingRect
            anchor = .init(min(anchor.x, rect.minX), min(anchor.y, rect.minY))
        }
        let snappedOffset = grid.snappedOffset(anchor, offset: offset)
        guard !snappedOffset.isZero else { return }
        events.append(.path(.init(pathIds: pathIds, .move(.init(offset: snappedOffset)))))
    }

    // MARK: single path update actions

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
        let snappedOffset = grid.snappedOffset(endingNode.position, offset: offset)
        guard !snappedOffset.isZero else { return }
        let node = PathNode(position: endingNode.position + snappedOffset)
        events.append(.path(.init(pathId: pathId, .createNode(.init(prevNodeId: prevNodeId, nodeId: newNodeId, node: node)))))
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
        let snappedOffset = grid.snappedOffset(position, offset: offset)

        let newNode = PathNode(position: position + snappedOffset, cubicIn: before.toCubicIn, cubicOut: after.fromCubicOut)
        fromNode.cubicOut = before.fromCubicOut
        toNode.cubicIn = after.toCubicIn

        events.append(.path(.init(pathId: pathId, [
            .createNode(.init(prevNodeId: fromNodeId, nodeId: newNodeId, node: newNode)),
            .updateNode(.init(nodeId: fromNodeId, node: fromNode)),
            .updateNode(.init(nodeId: toNodeId, node: toNode)),
        ])))
    }

    func collect(events: inout [DocumentEvent.Single], pathId: UUID, of action: PathAction.Update.DeleteNodes) {
        let nodeIds = action.nodeIds
        guard let path = pathStore.get(id: pathId) else { return }
        if path.nodes.count - nodeIds.count < 2 {
            events.append(.path(.init(pathId: pathId, .delete(.init()))))
            return
        }
        for nodeId in nodeIds {
            events.append(.path(.init(pathId: pathId, .deleteNode(.init(nodeIds: [nodeId])))))
        }
    }

    func collect(events: inout [DocumentEvent.Single], pathId: UUID, of action: PathAction.Update.UpdateNode) {
        let nodeId = action.nodeId,
            node = action.node
        events.append(.path(.init(pathId: pathId, .updateNode(.init(nodeId: nodeId, node: node)))))
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
        events.append(.path(.init(pathId: pathId, [
            .updateNode(.init(nodeId: fromNodeId, node: fromNode)),
            .updateNode(.init(nodeId: toNodeId, node: toNode)),
        ])))
    }

    func collect(events: inout [DocumentEvent.Single], pathId: UUID, of action: PathAction.Update.MoveNodes) {
        let nodeIds = action.nodeIds,
            offset = action.offset
        guard let path = pathStore.get(id: pathId),
              let firstId = nodeIds.first,
              let firstNode = path.node(id: firstId) else { return }
        let snappedOffset = grid.snappedOffset(firstNode.position, offset: offset)
        guard !snappedOffset.isZero else { return }

        var kinds: [PathEvent.Kind] = []
        defer { events.append(.path(.init(pathId: pathId, kinds))) }

        for nodeId in nodeIds {
            guard var node = path.node(id: nodeId) else { continue }
            node.position += snappedOffset
            kinds.append(.updateNode(.init(nodeId: nodeId, node: node)))
        }
    }

    func collect(events: inout [DocumentEvent.Single], pathId: UUID, of action: PathAction.Update.MoveNodeControl) {
        let nodeId = action.nodeId,
            offset = action.offset,
            controlType = action.controlType
        guard let path = pathStore.get(id: pathId),
              let node = path.node(id: nodeId),
              let property = pathStore.property(id: pathId) else { return }

        let nodeType = property.nodeType(id: nodeId)
        var kinds: [PathEvent.Kind] = []

        switch controlType {
        case .cubicIn:
            let snappedOffset = grid.snappedOffset(node.positionIn, offset: offset)
            guard !snappedOffset.isZero else { return }
            let cubicIn = node.cubicIn + snappedOffset,
                cubicOut = nodeType.map(current: node.cubicOut, opposite: cubicIn)
            kinds.append(.updateNode(.init(nodeId: nodeId, node: .init(position: node.position, cubicIn: cubicIn, cubicOut: cubicOut))))
        case .cubicOut:
            let snappedOffset = grid.snappedOffset(node.positionOut, offset: offset)
            guard !snappedOffset.isZero else { return }
            let cubicOut = node.cubicOut + snappedOffset,
                cubicIn = nodeType.map(current: node.cubicIn, opposite: cubicOut)
            kinds.append(.updateNode(.init(nodeId: nodeId, node: .init(position: node.position, cubicIn: cubicIn, cubicOut: cubicOut))))
        case .quadraticOut:
            guard let segment = path.segment(fromId: nodeId),
                  let quadratic = segment.quadratic else { return }
            let snappedOffset = grid.snappedOffset(quadratic, offset: offset)
            guard !snappedOffset.isZero,
                  let segment = path.segment(fromId: nodeId),
                  let quadratic = segment.quadratic,
                  let nextId = path.nodeId(after: nodeId),
                  let next = path.node(id: nextId) else { return }
            let newQuadratic = quadratic + snappedOffset,
                newSegment = PathSegment(from: segment.from, to: segment.to, quadratic: newQuadratic)
            kinds.append(.updateNode(.init(nodeId: nodeId, node: .init(position: node.position, cubicIn: node.cubicIn, cubicOut: newSegment.fromCubicOut))))
            kinds.append(.updateNode(.init(nodeId: nextId, node: .init(position: next.position, cubicIn: newSegment.toCubicIn, cubicOut: next.cubicOut))))
        }

        events.append(.path(.init(pathId: pathId, kinds)))
    }

    func collect(events: inout [DocumentEvent.Single], pathId: UUID, of action: PathAction.Update.Merge) {
        let endingNodeId = action.endingNodeId,
            mergedPathId = action.mergedPathId,
            mergedEndingNodeId = action.mergedEndingNodeId
        events.append(.path(.init(pathId: pathId, .merge(.init(endingNodeId: endingNodeId, mergedPathId: mergedPathId, mergedEndingNodeId: mergedEndingNodeId)))))
    }

    func collect(events: inout [DocumentEvent.Single], pathId: UUID, of action: PathAction.Update.Split) {
        let nodeId = action.nodeId,
            newNodeId = action.newNodeId,
            newPathId = action.newPathId
        events.append(.path(.init(pathId: pathId, .split(.init(nodeId: nodeId, newPathId: newPathId, newNodeId: newNodeId)))))
    }

    func collect(events: inout [DocumentEvent.Single], pathId: UUID, of action: PathAction.Update.SetNodeType) {
        let nodeIds = action.nodeIds,
            nodeType = action.nodeType
        events.append(.path(.init(pathId: pathId, .setNodeType(.init(nodeIds: nodeIds, nodeType: nodeType)))))
    }

    func collect(events: inout [DocumentEvent.Single], pathId: UUID, of action: PathAction.Update.SetSegmentType) {
        let fromNodeIds = action.fromNodeIds,
            segmentType = action.segmentType
        events.append(.path(.init(pathId: pathId, .setSegmentType(.init(fromNodeIds: fromNodeIds, segmentType: segmentType)))))
    }
}

// MARK: events of symbol action

private extension DocumentUpdater {
    func collect(events: inout [DocumentEvent.Single], of action: SymbolAction) {
        switch action {
        case let .create(action): collect(events: &events, of: action)
        case let .resize(action): collect(events: &events, of: action)
        case let .setGrid(action): collect(events: &events, of: action)

        case let .delete(action): collect(events: &events, of: action)
        case let .move(action): collect(events: &events, of: action)
        }
    }

    func collect(events: inout [DocumentEvent.Single], of action: SymbolAction.Create) {
        let symbolId = action.symbolId,
            origin = action.origin,
            size = action.size
        events.append(.symbol(.init(symbolId: symbolId, .create(.init(origin: origin, size: size, grids: [])))))
    }

    func collect(events: inout [DocumentEvent.Single], of action: SymbolAction.Resize) {
        let symbolId = action.symbolId,
            align = action.align,
            offset = action.offset
        guard let symbol = symbolStore.get(id: symbolId) else { return }
        var origin = symbol.origin,
            size = symbol.size
        switch align {
        case .topLeading:
            origin += offset
            size -= offset
        case .topTrailing:
            origin.y += offset.dy
            size.width += offset.dx
            size.height -= offset.dy
        case .bottomLeading:
            origin.x += offset.dx
            size.width -= offset.dx
            size.height += offset.dy
        case .bottomTrailing:
            size += offset
        default:
            return
        }
        size.width = max(size.width, 16)
        size.height = max(size.height, 16)
        events.append(.symbol(.init(symbolId: symbolId, .setBounds(.init(origin: origin, size: size)))))
    }

    func collect(events: inout [DocumentEvent.Single], of action: SymbolAction.SetGrid) {
        let symbolId = action.symbolId,
            index = action.index,
            grid = action.grid
        events.append(.symbol(.init(symbolId: symbolId, .setGrid(.init(index: index, grid: grid)))))
    }

    func collect(events: inout [DocumentEvent.Single], of action: SymbolAction.Delete) {
        let symbolIds = action.symbolIds
        events.append(.symbol(.init(symbolIds: symbolIds, .delete(.init()))))
    }

    func collect(events: inout [DocumentEvent.Single], of action: SymbolAction.Move) {
        let symbolIds = action.symbolIds,
            offset = action.offset
        guard let symbolId = symbolIds.first,
              let symbol = symbolStore.get(id: symbolId) else { return }
        let anchor = symbol.boundingRect.minPoint
        let snappedOffset = grid.snappedOffset(anchor, offset: offset)
        guard !snappedOffset.isZero else { return }
        events.append(.symbol(.init(symbolIds: symbolIds, .move(.init(offset: snappedOffset)))))
    }
}

// MARK: events of item action

private extension DocumentUpdater {
    func collect(events: inout [DocumentEvent.Single], of action: ItemAction) {
        switch action {
        case let .group(action): collect(events: &events, of: action)
        case let .ungroup(action): collect(events: &events, of: action)
        case let .reorder(action): collect(events: &events, of: action)

        case let .setName(action): collect(events: &events, of: action)
        case let .setLocked(action): collect(events: &events, of: action)
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
            events.append(.symbol(.init(symbolId: symbol.id, .setMembers(.init(members: symbol.members)))))
        }

        func adjustMembers(in group: Item.Group) {
            var group = group
            guard inGroupId == group.id || hasGrouped(in: members) else { return }
            removeGrouped(from: &group.members)
            if inGroupId == group.id {
                group.members.append(group.id)
            }
            events.append(.item(.init(itemId: group.id, .setGroup(.init(members: group.members)))))
        }

        adjustRootMembers()
        for group in itemStore.allGroups(symbolId: symbolId) {
            adjustMembers(in: group)
        }

        events.append(.item(.init(itemId: groupId, .setGroup(.init(members: members)))))
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
            events.append(.symbol(.init(symbolId: symbol.id, .setMembers(.init(members: symbol.members)))))
        }

        func adjustMembers(in group: Item.Group) {
            var group = group
            guard hasUngrouped(in: group.members) else { return }
            expandUngrouped(in: &group.members)
            events.append(.item(.init(itemId: group.id, .setGroup(.init(members: group.members)))))
        }

        for groupId in groupIds {
            events.append(.item(.init(itemId: groupId, .setGroup(.init(members: [])))))
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
        var idToGroupMembers = [UUID: [UUID]](),
            symbolMembers: [UUID]?
        guard let symbol = itemStore.symbol(of: itemId),
              itemStore.symbolId(of: toItemId) == symbol.id, // not in the same symbol
              itemStore.ancestorIds(of: toItemId).firstIndex(of: itemId) == nil else { return } // cyclic moving
        if let parentId, var members = itemStore.group(id: parentId)?.members {
            members.removeAll { $0 == itemId }
            idToGroupMembers[parentId] = members
        } else {
            var members = symbol.members
            members.removeAll { $0 == itemId }
            symbolMembers = members
        }
        if let toParentId, let members = itemStore.group(id: toParentId)?.members {
            var members = idToGroupMembers[toParentId] ?? members
            let index = members.firstIndex(of: toItemId) ?? 0
            members.insert(itemId, at: isAfter ? members.index(after: index) : index)
            idToGroupMembers[toParentId] = members
        } else {
            var members = symbolMembers ?? symbol.members
            let index = members.firstIndex(of: toItemId) ?? 0
            members.insert(itemId, at: isAfter ? members.index(after: index) : index)
            symbolMembers = members
        }
        for (groupId, members) in idToGroupMembers {
            events.append(.item(.init(itemId: groupId, .setGroup(.init(members: members)))))
        }
        if let symbolMembers {
            events.append(.symbol(.init(symbolId: symbol.id, .setMembers(.init(members: symbolMembers)))))
        }
    }

    func collect(events: inout [DocumentEvent.Single], of action: ItemAction.SetName) {
        let itemId = action.itemId,
            name = action.name
        events.append(.item(.init(itemId: itemId, .setName(.init(name: name)))))
    }

    func collect(events: inout [DocumentEvent.Single], of action: ItemAction.SetLocked) {
        let itemIds = action.itemIds,
            locked = action.locked
        events.append(.item(.init(itemIds: itemIds, .setLocked(.init(locked: locked)))))
    }
}

// MARK: events of world action

private extension DocumentUpdater {
    func collect(events: inout [DocumentEvent.Single], of action: WorldAction) {
        switch action {
        case let .reorder(action): collect(events: &events, of: action)
        case let .setGrid(action): collect(events: &events, of: action)
        }
    }

    func collect(events: inout [DocumentEvent.Single], of action: WorldAction.SetGrid) {
        let grid = action.grid
        events.append(.world(.setGrid(.init(grid: grid))))
    }

    func collect(events: inout [DocumentEvent.Single], of action: WorldAction.Reorder) {
        let symbolId = action.symbolId,
            toSymbolId = action.toSymbolId,
            isAfter = action.isAfter
        guard symbolId != toSymbolId else { return } // not moved
        var symbolIds = worldStore.symbolIds
        symbolIds.removeAll { $0 == symbolId }
        let index = symbolIds.firstIndex(of: toSymbolId) ?? 0
        symbolIds.insert(symbolId, at: isAfter ? symbolIds.index(after: index) : index)
        events.append(.world(.setSymbolIds(.init(symbolIds: symbolIds))))
    }
}
