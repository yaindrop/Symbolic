import Foundation

fileprivate let subtracer = tracer.tagged("CanvasItemService")

typealias CanvasItemMap = OrderedMap<UUID, CanvasItem>

fileprivate protocol CanvasItemStoreProtocol {
    var map: CanvasItemMap { get }

    var items: [CanvasItem] { get }

    func item(id: UUID) -> CanvasItem?
}

// MARK: - CanvasItemStore

class CanvasItemStore: Store, CanvasItemStoreProtocol {
    @Trackable var map = CanvasItemMap()

    var items: [CanvasItem] { map.values }

    func item(id: UUID) -> CanvasItem? { map.value(key: id) }

    fileprivate func update(map: CanvasItemMap) {
        update { $0(\._map, map) }
    }
}

// MARK: - PendingCanvasItemStore

class PendingCanvasItemStore: Store, CanvasItemStoreProtocol {
    @Trackable var map = CanvasItemMap()
    @Trackable fileprivate var active: Bool = false

    var items: [CanvasItem] { map.values }

    func item(id: UUID) -> CanvasItem? { map.value(key: id) }

    fileprivate func update(map: CanvasItemMap) {
        update { $0(\._map, map) }
    }

    fileprivate func update(active: Bool) {
        update { $0(\._active, active) }
    }
}

// MARK: - CanvasItemService

struct CanvasItemService: CanvasItemStoreProtocol {
    let pathService: PathService
    let store: CanvasItemStore
    let pendingStore: PendingCanvasItemStore

    var map: CanvasItemMap { pendingStore.active ? pendingStore.map : store.map }

    var items: [CanvasItem] { pendingStore.active ? pendingStore.items : store.items }

    func item(id: UUID) -> CanvasItem? { pendingStore.active ? pendingStore.item(id: id) : store.item(id: id) }

    func loadDocument(_ document: Document) {
        let _r = subtracer.range("load document \(pendingStore.active)", type: .intent); defer { _r() }
        withStoreUpdating {
            clear()
            for event in document.events {
                loadEvent(event)
            }
        }
    }

    func loadPendingEvent(_ event: DocumentEvent?) {
        let _r = subtracer.range("load pending event"); defer { _r() }
        guard let event else {
            pendingStore.update(active: false)
            return
        }

        withStoreUpdating {
            pendingStore.update(active: true)
            pendingStore.update(map: store.map.cloned)
            loadEvent(event)
        }
    }

    private func update(map: CanvasItemMap) {
        if pendingStore.active {
            pendingStore.update(map: map)
        } else {
            store.update(map: map)
        }
    }
}

// MARK: - modify item map

extension CanvasItemService {
    private func add(item: CanvasItem) {
        let _r = subtracer.range("add"); defer { _r() }
        if case let .path(path) = item.kind {
            guard pathService.path(id: path.id) != nil else { return }
        }
        update(map: map.with { $0[item.id] = item })
    }

    private func remove(itemId: UUID) {
        let _r = subtracer.range("remove"); defer { _r() }
        guard item(id: itemId) != nil else { return }
        update(map: map.with { $0.removeValue(forKey: itemId) })
    }

    private func update(item: CanvasItem) {
        let _r = subtracer.range("update"); defer { _r() }
        if case let .path(path) = item.kind {
            guard pathService.path(id: path.id) != nil else { remove(itemId: item.id); return }
        }
        guard self.item(id: item.id) != nil else { return }
        update(map: map.with { $0[item.id] = item })
    }

    private func clear() {
        let _r = subtracer.range("clear"); defer { _r() }
        update(map: .init())
    }
}

// MARK: - event loaders

extension CanvasItemService {
    private func loadEvent(_ event: DocumentEvent) {
        let _r = subtracer.range("load document event \(event.id)", type: .intent); defer { _r() }
        switch event.kind {
        case let .pathEvent(event):
            loadEvent(event)
        case let .compoundEvent(event):
            loadEvent(event)
        }
    }

    private func loadEvent(_ event: CompoundEvent) {
        event.events.forEach {
            switch $0 {
            case let .pathEvent(pathEvent):
                loadEvent(pathEvent)
            }
        }
    }

    private func loadEvent(_ event: PathEvent) {
        let _r = subtracer.range("load event"); defer { _r() }
        switch event {
        case let .create(event):
            loadAffectedPaths(event.path.id)
        case let .delete(event):
            loadAffectedPaths(event.pathId)
        case let .update(event):
            loadEvent(event)
        }
    }

    // MARK: path update event loaders

    private func loadEvent(_ event: PathEvent.Update) {
        let pathId = event.pathId
        switch event.kind {
        case .move, .nodeCreate, .nodeDelete, .nodeUpdate, .edgeUpdate:
            loadAffectedPaths(pathId)
        case let .merge(event):
            loadAffectedPaths(pathId, event.mergedPathId)
        case let .nodeBreak(event):
            loadAffectedPaths(pathId, event.newPathId)
        case let .edgeBreak(event):
            loadAffectedPaths(pathId, event.newPathId)
        }
    }

    private func loadAffectedPaths(_ pathIds: UUID...) {
        for pathId in pathIds {
            if pathService.path(id: pathId) == nil {
                remove(itemId: pathId)
            } else if item(id: pathId) == nil {
                add(item: .init(kind: .path(.init(id: pathId)), zIndex: 0))
            }
        }
    }
}
