import Foundation

private let subtracer = tracer.tagged("FocusedPathService")

// MARK: - FocusedPathStore

class FocusedPathStore: Store {
    @Trackable var activeNodeIds = Set<UUID>()

    fileprivate func update(activeNodeIds: Set<UUID>) {
        withFastAnimation {
            withStoreUpdating {
                update { $0(\._activeNodeIds, activeNodeIds) }
            }
        }
    }
}

// MARK: - FocusedPathService

struct FocusedPathService {
    let activeItem: ActiveItemService
    let store: FocusedPathStore
}

// MARK: selectors

extension FocusedPathService {
    var activeNodeIds: Set<UUID> { store.activeNodeIds }

    var activeSegmentIds: Set<UUID> {
        guard let path = activeItem.focusedPath else { return [] }
        return activeNodeIds.filter {
            guard let nextId = path.node(after: $0)?.id else { return false }
            return activeNodeIds.contains(nextId)
        }
    }

    var focusedNodeId: UUID? { activeNodeIds.count == 1 ? activeNodeIds.first : nil }

    var focusedSegmentId: UUID? { activeNodeIds.count == 2 ? activeSegmentIds.first : nil }
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

    func clearFocus() {
        let _r = subtracer.range(type: .intent, "clear focus"); defer { _r() }
        store.update(activeNodeIds: [])
    }

    func onFocusedPathChanged() {
        clearFocus()
    }
}
