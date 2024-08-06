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

    func nodeBounds(id nodeId: UUID) -> CGRect? {
        guard let path = activeItem.focusedPath,
              let node = path.node(id: nodeId) else { return nil }
        return .init(containing: [node.position, node.positionIn, node.positionOut])
    }

    func segmentBounds(fromId: UUID) -> CGRect? {
        guard let path = activeItem.focusedPath,
              let segment = path.segment(fromId: fromId) else { return nil }
        return .init(containing: [segment.from, segment.to, segment.fromOut, segment.toIn])
    }

    func subpathBounds(from: Int, to: Int) -> CGRect? {
        guard let path = activeItem.focusedPath else { return nil }
        if from == to {
            guard let nodeId = path.nodeId(at: from) else { return nil }
            return nodeBounds(id: nodeId)
        } else {
            guard let subpath = path.subpath(from: from, to: to) else { return nil }
            return subpath.boundingRect
        }
    }

    var activeNodesBounds: CGRect? {
        guard let nodeBounds = activeNodeIndexPairs.completeMap({ subpathBounds(from: $0.first, to: $0.second) }),
              let bounds = CGRect(union: nodeBounds),
              let pathBounds = activeItem.focusedPath?.boundingRect else { return nil }
        let minY = min(bounds.minY, pathBounds.minY),
            maxY = max(bounds.maxY, pathBounds.maxY)
        return .init(origin: .init(bounds.minX, minY), size: .init(bounds.width, maxY - minY))
    }
}

// MARK: bezier control

extension FocusedPathService {
    var cubicInNodeIds: [UUID] {
        guard let path = activeItem.focusedPath,
              let pathProperty = activeItem.focusedPathProperty else { return [] }
        let focusedSegmentId = focusedSegmentId,
            focusedNodeId = focusedNodeId
        return path.nodeIds.filter {
            guard let prevId = path.nodeId(before: $0),
                  let segment = path.segment(fromId: prevId),
                  focusedSegmentId == prevId || focusedNodeId == $0 else { return false }
            let segmentType = pathProperty.segmentType(id: prevId)
            return segmentType.activeType(segment: segment, isOut: false) == .cubic
        }
    }

    var cubicOutNodeIds: [UUID] {
        guard let path = activeItem.focusedPath,
              let pathProperty = activeItem.focusedPathProperty else { return [] }
        let focusedSegmentId = focusedSegmentId,
            focusedNodeId = focusedNodeId
        return path.nodeIds.filter {
            guard let segment = path.segment(fromId: $0),
                  focusedSegmentId == $0 || focusedNodeId == $0 else { return false }
            let segmentType = pathProperty.segmentType(id: $0)
            return segmentType.activeType(segment: segment, isOut: true) == .cubic
        }
    }

    var quadraticFromNodeIds: [UUID] {
        guard let path = activeItem.focusedPath,
              let pathProperty = activeItem.focusedPathProperty else { return [] }
        let focusedSegmentId = focusedSegmentId,
            focusedNodeId = focusedNodeId
        return path.nodeIds.filter {
            guard let segment = path.segment(fromId: $0),
                  let nextId = path.nodeId(after: $0),
                  focusedSegmentId == $0 || focusedNodeId == $0 || focusedNodeId == nextId else { return false }
            let segmentType = pathProperty.segmentType(id: $0)
            return segmentType.activeType(segment: segment, isOut: false) == .quadratic
        }
    }

    func controlNodeId(closestTo point: Point2) -> (nodeId: UUID, type: PathBezierControlType)? {
        var result: (id: UUID, type: PathBezierControlType, distance: Scalar)?
        guard let path = activeItem.focusedPath else { return nil }
        for nodeId in cubicInNodeIds {
            guard let node = path.node(id: nodeId) else { continue }
            let distance = node.positionIn.distance(to: point)
            if distance < result?.distance ?? .infinity {
                result = (nodeId, .cubicIn, distance)
            }
        }
        for nodeId in cubicOutNodeIds {
            guard let node = path.node(id: nodeId) else { continue }
            let distance = node.positionOut.distance(to: point)
            if distance < result?.distance ?? .infinity {
                result = (nodeId, .cubicOut, distance)
            }
        }
        for nodeId in quadraticFromNodeIds {
            guard let segment = path.segment(fromId: nodeId),
                  let position = segment.quadratic else { continue }
            let distance = position.distance(to: point)
            if distance < result?.distance ?? .infinity {
                result = (nodeId, .quadratic, distance)
            }
        }
        return result.map { ($0.id, $0.type) }
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
        withStoreUpdating(configs: .init(animation: .fast)) {
            if selectingNodes {
                clear()
            } else {
                store.update(selectingNodes: true)
            }
        }
    }

    func toggleSelection(nodeIds: [UUID]) {
        let _r = subtracer.range(type: .intent, "toggleSelection of \(nodeIds)"); defer { _r() }
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
