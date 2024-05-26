import Foundation

fileprivate let subtracer = tracer.tagged("CanvasGroupService")

typealias CanvasGroupMap = [UUID: CanvasGroup]

fileprivate protocol CanvasGroupStoreProtocol {
    var map: CanvasGroupMap { get }

    func group(id: UUID) -> CanvasGroup?
}

class CanvasGroupStore: Store, CanvasGroupStoreProtocol {
    @Trackable var map = CanvasGroupMap()

    func group(id: UUID) -> CanvasGroup? { map.value(key: id) }
}

class PendingCanvasGroupStore: Store, CanvasGroupStoreProtocol {
    @Trackable var map = CanvasGroupMap()
    @Trackable fileprivate var active: Bool = false

    func group(id: UUID) -> CanvasGroup? { map.value(key: id) }

    fileprivate func update(active: Bool) {
        update { $0(\._active, active) }
    }
}

struct CanvasGroupService: CanvasGroupStoreProtocol {
    let store: CanvasGroupStore
    let pendingStore: PendingCanvasGroupStore

    var map: CanvasGroupMap { pendingStore.active ? pendingStore.map : store.map }

    func group(id: UUID) -> CanvasGroup? { pendingStore.active ? pendingStore.group(id: id) : store.group(id: id) }

    func pathIds(in groupId: UUID) -> [UUID] {
        var pathIds: [UUID] = []
        func collect(_ groupId: UUID) {
            guard let group = group(id: groupId) else { return }
            for member in group.members {
                switch member {
                case let .path(path): pathIds.append(path.id)
                case let .group(group): collect(group.id)
                }
            }
        }
        collect(groupId)
        return pathIds
    }
}
