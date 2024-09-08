import Foundation

private let subtracer = tracer.tagged("FocusedPathService")

// MARK: - FocusedPathStore

enum PathNodeActiveState: Equatable {
    case none
    case active(Set<UUID>)
    case focusedNode(UUID)
    case focusedSegment(from: UUID, to: UUID)
}

class FocusedPathStore: Store {
    @Trackable var state: PathNodeActiveState = .none
}

private extension FocusedPathStore {
    func update(state: PathNodeActiveState) {
        update { $0(\._state, state) }
    }
}

// MARK: - FocusedPathService

struct FocusedPathService {
    let store: FocusedPathStore
    let activeItem: ActiveItemService
}

// MARK: selectors

extension FocusedPathService {
    var state: PathNodeActiveState { store.state }

    var activeNodeIds: Set<UUID> {
        switch state {
        case let .active(ids): ids
        case let .focusedNode(nodeId): [nodeId]
        case let .focusedSegment(from, to): [from, to]
        default: []
        }
    }

    var selectingNodes: Bool {
        switch state {
        case .active: true
        default: false
        }
    }

    var activeSegmentIds: Set<UUID> {
        guard let path = activeItem.focusedPath else { return [] }
        return activeNodeIds.filter {
            guard let nextId = path.nodeId(after: $0) else { return false }
            return activeNodeIds.contains(nextId)
        }
    }

    var focusedNodeId: UUID? {
        switch state {
        case let .focusedNode(nodeId): nodeId
        default: nil
        }
    }

    var focusedSegmentId: UUID? {
        switch state {
        case let .focusedSegment(from, _): from
        default: nil
        }
    }

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
                  !(segment.toCubicIn ~== .zero),
                  focusedSegmentId == prevId || focusedNodeId == $0 else { return false }
            let segmentType = pathProperty.segmentType(id: prevId).activeType(segment: segment)
            return segmentType == .cubic
        }
    }

    var cubicOutNodeIds: [UUID] {
        guard let path = activeItem.focusedPath,
              let pathProperty = activeItem.focusedPathProperty else { return [] }
        let focusedSegmentId = focusedSegmentId,
            focusedNodeId = focusedNodeId
        return path.nodeIds.filter {
            guard let segment = path.segment(fromId: $0),
                  !(segment.fromCubicOut ~== .zero),
                  focusedSegmentId == $0 || focusedNodeId == $0 else { return false }
            let segmentType = pathProperty.segmentType(id: $0).activeType(segment: segment)
            return segmentType == .cubic
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
            let segmentType = pathProperty.segmentType(id: $0).activeType(segment: segment)
            return segmentType == .quadratic
        }
    }

    func controlNodeId(closestTo point: Point2) -> (nodeId: UUID, type: PathNodeControlType)? {
        var result: (id: UUID, type: PathNodeControlType, distance: Scalar)?
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
                result = (nodeId, .quadraticOut, distance)
            }
        }
        return result.map { ($0.id, $0.type) }
    }
}

// MARK: actions

extension FocusedPathService {
    func setFocus(node id: UUID) {
        let _r = subtracer.range(type: .intent, "set focus node \(id)"); defer { _r() }
        store.update(state: .focusedNode(id))
    }

    func setFocus(segment fromNodeId: UUID) {
        let _r = subtracer.range(type: .intent, "set focus segment from \(fromNodeId)"); defer { _r() }
        guard let path = activeItem.focusedPath,
              let toId = path.nodeId(after: fromNodeId) else { return }
        store.update(state: .focusedSegment(from: fromNodeId, to: toId))
    }

    func setSelecting(_ value: Bool) {
        let _r = subtracer.range(type: .intent, "set selecting \(value)"); defer { _r() }
        withStoreUpdating(.animation(.fast)) {
            if value {
                store.update(state: .active([]))
            } else {
                selectionClear()
            }
        }
    }

    func selection(add ids: [UUID]) {
        let _r = subtracer.range(type: .intent, "selection add \(ids)"); defer { _r() }
        store.update(state: .active(activeNodeIds.union(ids)))
    }

    func selection(remove ids: [UUID]) {
        let _r = subtracer.range(type: .intent, "selection remove \(ids)"); defer { _r() }
        store.update(state: .active(activeNodeIds.subtracting(ids)))
    }

    func selection(toggle nodeIds: [UUID]) {
        let _r = subtracer.range(type: .intent, "selection toggle \(nodeIds)"); defer { _r() }
        if activeNodeIds.isSuperset(of: nodeIds) {
            selection(remove: nodeIds)
        } else {
            selection(add: nodeIds)
        }
    }

    func selection(activeNodeIds: Set<UUID>, dragFrom nodeId: UUID, offset: Vector2) {
        let _r = subtracer.range(type: .intent, "selection drag from \(nodeId), offset \(offset)"); defer { _r() }
        guard let path = activeItem.focusedPath,
              let node = path.node(id: nodeId),
              let toNodeId = path.nodeId(closestTo: node.position + offset),
              var i = path.nodeIndex(id: nodeId),
              var j = path.nodeIndex(id: toNodeId) else { return }
        if i > j {
            (i, j) = (j, i)
        }
        let nodeIds = path.indices(from: i, to: j).map { path.nodeId(at: $0) }.complete()
        guard var nodeIds else { return }
        if path.isClosed {
            let reverseNodeIds = path.indices(from: j, to: i).map { path.nodeId(at: $0) }.complete()
            guard let reverseNodeIds else { return }
            let diff = self.activeNodeIds.count + nodeIds.count - 2 * self.activeNodeIds.intersection(nodeIds).count,
                reverseDiff = self.activeNodeIds.count + reverseNodeIds.count - 2 * self.activeNodeIds.intersection(reverseNodeIds).count
            if reverseDiff < diff {
                nodeIds = reverseNodeIds
            }
        }
        if activeNodeIds.contains(nodeId) {
            store.update(state: .active(activeNodeIds.subtracting(nodeIds)))
        } else {
            store.update(state: .active(activeNodeIds.union(nodeIds)))
        }
    }

    func selectionInvert() {
        let _r = subtracer.range(type: .intent, "selection invert"); defer { _r() }
        guard let path = activeItem.focusedPath else { return }
        store.update(state: .active(.init(path.nodeIds.filter { !activeNodeIds.contains($0) })))
    }

    func selectionClear() {
        let _r = subtracer.range(type: .intent, "selection clear"); defer { _r() }
        withStoreUpdating {
            store.update(state: .none)
        }
    }
}

extension FocusedPathService {
    func onTap(node nodeId: UUID) {
        if selectingNodes {
            selection(toggle: [nodeId])
        } else {
            let focused = focusedNodeId == nodeId
            focused ? selectionClear() : setFocus(node: nodeId)
        }
    }

    func onTap(segment fromId: UUID) {
        if selectingNodes {
            guard let path = activeItem.focusedPath,
                  let toId = path.nodeId(after: fromId) else { return }
            selection(toggle: [fromId, toId])
        } else {
            let focused = focusedSegmentId == fromId
            focused ? selectionClear() : setFocus(segment: fromId)
        }
    }
}
