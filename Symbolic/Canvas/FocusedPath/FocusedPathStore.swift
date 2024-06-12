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
    let viewport: ViewportService
    let activeItem: ActiveItemService
    let store: FocusedPathStore
}

// MARK: selectors

extension FocusedPathService {
    var activeNodeIds: Set<UUID> { store.activeNodeIds }
    var selectingNodes: Bool { store.selectingNodes }

    var activeSegmentIds: Set<UUID> {
        guard let path = activeItem.focusedPath else { return [] }
        return activeNodeIds.filter {
            guard let nextId = path.node(after: $0)?.id else { return false }
            return activeNodeIds.contains(nextId)
        }
    }

    var focusedNodeId: UUID? { !selectingNodes && activeNodeIds.count == 1 ? activeNodeIds.first : nil }

    var focusedSegmentId: UUID? { !selectingNodes && activeNodeIds.count == 2 ? activeSegmentIds.first : nil }

    var activeNodeIndexPairs: [Pair<Int, Int>] {
        guard let path = activeItem.focusedPath else { return [] }
        return path.continuousNodeIndexPairs(nodeIds: activeNodeIds)
    }

    func subpath(from: Int, to: Int) -> Path? {
        guard let path = activeItem.focusedPath else { return nil }
        return path.subpath(from: from, to: to)
    }

    func nodesBounds(from: Int, to: Int) -> CGRect? {
        guard let path = activeItem.focusedPath else { return nil }
        if from == to {
            guard let node = path.node(at: from) else { return nil }
            return CGRect(center: node.position, size: .zero)
        } else {
            guard let subpath = subpath(from: from, to: to) else { return nil }
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

// MARK: actions

extension FocusedPathService {
    func setFocus(node id: UUID) {
        let _r = subtracer.range(type: .intent, "set focus node \(id)"); defer { _r() }
        store.update(activeNodeIds: [id])
    }

    func setFocus(segment fromNodeId: UUID) {
        let _r = subtracer.range(type: .intent, "set focus segment from \(fromNodeId)"); defer { _r() }
        guard let path = activeItem.focusedPath, let toId = path.node(after: fromNodeId)?.id else { return }
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
        store.update(activeNodeIds: activeNodeIds.with { $0.formUnion(ids) })
    }

    func selectRemove(node ids: [UUID]) {
        let _r = subtracer.range(type: .intent, "selectRemove \(ids)"); defer { _r() }
        store.update(activeNodeIds: activeNodeIds.with { $0.subtract(ids) })
    }

    func toggleSelectingNodes() {
        let _r = subtracer.range(type: .intent, "toggleSelectingNodes from \(selectingNodes)"); defer { _r() }
        if selectingNodes {
            clear()
        } else {
            store.update(selectingNodes: true)
        }
    }
}
