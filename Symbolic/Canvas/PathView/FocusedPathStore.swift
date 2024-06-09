import Foundation

private let subtracer = tracer.tagged("FocusedPathService")

// MARK: - FocusedPathStore

class FocusedPathStore: Store {
    @Trackable var activeNodeIds = Set<UUID>()
    @Trackable var selectingNodes = false

    fileprivate func update(activeNodeIds: Set<UUID>) {
        update { $0(\._activeNodeIds, activeNodeIds) }
    }

    fileprivate func update(selectingNodes: Bool) {
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

    var focusedNodeBounds: CGRect? {
        guard let focusedNodeId else { return nil }
        guard let node = activeItem.focusedPath?.node(id: focusedNodeId) else { return nil }
        guard !store.selectingNodes else { return nil }
        return .init(center: node.position.applying(viewport.toView), size: .init(10, 10))
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

    func setSelectingNodes(_ selectingNodes: Bool) {
        let _r = subtracer.range(type: .intent, "setSelectingNodes \(selectingNodes)"); defer { _r() }
        store.update(selectingNodes: selectingNodes)
    }

    func selectAdd(node ids: [UUID]) {
        let _r = subtracer.range(type: .intent, "selectAdd \(ids)"); defer { _r() }
        store.update(activeNodeIds: activeNodeIds.with { $0.formUnion(ids) })
    }

    func selectRemove(node ids: [UUID]) {
        let _r = subtracer.range(type: .intent, "selectRemove \(ids)"); defer { _r() }
        store.update(activeNodeIds: activeNodeIds.with { $0.subtract(ids) })
    }
}
