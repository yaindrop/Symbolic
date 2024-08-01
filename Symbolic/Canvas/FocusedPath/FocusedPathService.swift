import Foundation

private let subtracer = tracer.tagged("FocusedPathService")

// MARK: - FocusedPathStore

class FocusedPathStore: Store {
    @Trackable var activeNodeIds = Set<UUID>()
    @Trackable var selectingNodes = false
}

private extension FocusedPathStore {
    func update(activeNodeIds: Set<UUID>) {
        update { $0(\._activeNodeIds, activeNodeIds) }
    }

    func update(selectingNodes: Bool) {
        update { $0(\._selectingNodes, selectingNodes) }
    }
}

// MARK: - FocusedPathService

struct FocusedPathService {
    let store: FocusedPathStore
    let activeItem: ActiveItemService
}

// MARK: selectors

extension FocusedPathService {
    var activeNodeIds: Set<UUID> { store.activeNodeIds }
    var selectingNodes: Bool { store.selectingNodes }

    var activeSegmentIds: Set<UUID> {
        guard let path = activeItem.focusedPath else { return [] }
        return activeNodeIds.filter {
            guard let nextId = path.nodeId(after: $0) else { return false }
            return activeNodeIds.contains(nextId)
        }
    }

    var focusedNodeId: UUID? { !selectingNodes && activeNodeIds.count == 1 ? activeNodeIds.first : nil }

    var focusedSegmentId: UUID? { !selectingNodes && activeNodeIds.count == 2 ? activeSegmentIds.first : nil }

    var activeNodeIndexPairs: [Pair<Int, Int>] {
        guard let path = activeItem.focusedPath else { return [] }
        return path.continuousNodeIndexPairs(nodeIds: activeNodeIds)
    }

    func nodesBounds(from: Int, to: Int) -> CGRect? {
        guard let path = activeItem.focusedPath else { return nil }
        if from == to {
            guard let node = path.node(at: from) else { return nil }
            return CGRect(center: node.position, size: .zero)
        } else {
            guard let subpath = path.subpath(from: from, to: to) else { return nil }
            return subpath.boundingRect
        }
    }

    var activeNodesBounds: CGRect? {
        guard let nodeBounds = activeNodeIndexPairs.completeMap({ nodesBounds(from: $0.first, to: $0.second) }) else { return nil }
        guard let unioned = CGRect(union: nodeBounds) else { return nil }
        guard let pathBounds = activeItem.focusedPath?.boundingRect else { return nil }
        return .init(origin: .init(unioned.origin.x, pathBounds.minY), size: .init(unioned.size.width, pathBounds.height))
    }
}

// MARK: bezier control

extension FocusedPathService {
    var controlInNodeIds: [UUID] {
        guard let path = activeItem.focusedPath,
              let pathProperty = activeItem.focusedPathProperty else { return [] }
        let focusedSegmentId = focusedSegmentId,
            focusedNodeId = focusedNodeId
        return path.nodeIds.filter {
            guard let prevId = path.nodeId(before: $0),
                  let node = path.node(id: $0) else { return false }
            let segmentType = pathProperty.segmentType(id: prevId),
                focused = focusedSegmentId == prevId || focusedNodeId == $0,
                valid = segmentType == .cubic || (segmentType == .auto && node.controlIn != .zero)
            return focused && valid
        }
    }

    var controlOutNodeIds: [UUID] {
        guard let path = activeItem.focusedPath,
              let pathProperty = activeItem.focusedPathProperty else { return [] }
        let focusedSegmentId = focusedSegmentId,
            focusedNodeId = focusedNodeId
        return path.nodeIds.filter {
            guard let node = path.node(id: $0) else { return false }
            let segmentType = pathProperty.segmentType(id: $0),
                focused = focusedSegmentId == $0 || focusedNodeId == $0,
                valid = segmentType == .cubic || (segmentType == .auto && node.controlOut != .zero)
            return focused && valid
        }
    }

    func controlNodeId(closestTo point: Point2) -> (nodeId: UUID, isControlOut: Bool)? {
        var result: (id: UUID, isControlOut: Bool, distance: Scalar)?
        guard let path = activeItem.focusedPath else { return nil }
        for nodeId in controlInNodeIds {
            guard let node = path.node(id: nodeId) else { continue }
            let distance = node.positionIn.distance(to: point)
            if distance < result?.distance ?? .infinity {
                result = (nodeId, false, distance)
            }
        }
        for nodeId in controlOutNodeIds {
            guard let node = path.node(id: nodeId) else { continue }
            let distance = node.positionOut.distance(to: point)
            if distance < result?.distance ?? .infinity {
                result = (nodeId, true, distance)
            }
        }
        return result.map { ($0.id, $0.isControlOut) }
    }
}

// MARK: actions

extension FocusedPathService {
    func setFocus(node id: UUID) {
        let _r = subtracer.range(type: .intent, "set focus node \(id)"); defer { _r() }
        store.update(activeNodeIds: [id])
    }

    func setFocus(segment fromNodeId: UUID) {
        let _r = subtracer.range(type: .intent, "set focus segment from \(fromNodeId)"); defer { _r() }
        guard let path = activeItem.focusedPath,
              let toId = path.nodeId(after: fromNodeId) else { return }
        store.update(activeNodeIds: [fromNodeId, toId])
    }

    func clear() {
        let _r = subtracer.range(type: .intent, "clear"); defer { _r() }
        withStoreUpdating {
            store.update(activeNodeIds: [])
            store.update(selectingNodes: false)
        }
    }

    func selectAdd(node ids: [UUID]) {
        let _r = subtracer.range(type: .intent, "selectAdd \(ids)"); defer { _r() }
        store.update(activeNodeIds: activeNodeIds.cloned { $0.formUnion(ids) })
    }

    func selectRemove(node ids: [UUID]) {
        let _r = subtracer.range(type: .intent, "selectRemove \(ids)"); defer { _r() }
        store.update(activeNodeIds: activeNodeIds.cloned { $0.subtract(ids) })
    }

    func toggleSelectingNodes() {
        let _r = subtracer.range(type: .intent, "toggleSelectingNodes from \(selectingNodes)"); defer { _r() }
        if selectingNodes {
            clear()
        } else {
            store.update(selectingNodes: true)
        }
    }

    func toggleSelection(nodeIds: [UUID]) {
        if activeNodeIds.isSuperset(of: nodeIds) {
            selectRemove(node: nodeIds)
        } else {
            selectAdd(node: nodeIds)
        }
    }

    func onTap(node nodeId: UUID) {
        if selectingNodes {
            toggleSelection(nodeIds: [nodeId])
        } else {
            let focused = focusedNodeId == nodeId
            focused ? clear() : setFocus(node: nodeId)
        }
    }

    func onTap(segment fromId: UUID) {
        if selectingNodes {
            guard let path = activeItem.focusedPath,
                  let toId = path.nodeId(after: fromId) else { return }
            toggleSelection(nodeIds: [fromId, toId])
        } else {
            let focused = focusedSegmentId == fromId
            focused ? clear() : setFocus(segment: fromId)
        }
    }
}
