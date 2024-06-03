import Foundation

private let subtracer = tracer.tagged("PathService")

typealias PathPropertyMap = [UUID: PathProperty]

// MARK: - PathPropertyStore

class PathPropertyStore: Store {
    @Trackable var map = PathPropertyMap()

    fileprivate func update(map: PathPropertyMap) {
        update { $0(\._map, map) }
    }
}

// MARK: - PendingPathPropertyStore

class PendingPathPropertyStore: PathPropertyStore {
    @Trackable fileprivate var active: Bool = false

    fileprivate func update(active: Bool) {
        update { $0(\._active, active) }
    }
}

// MARK: - PathPropertyService

struct PathPropertyService {
    let store: PathPropertyStore
    let pendingStore: PendingPathPropertyStore
}

// MARK: selectors

extension PathPropertyService {
    var map: PathPropertyMap { pendingStore.active ? pendingStore.map : store.map }
}
