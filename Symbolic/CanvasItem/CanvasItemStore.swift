import Foundation

fileprivate let subtracer = tracer.tagged("CanvasItemService")

typealias CanvasItemMap = [UUID: CanvasItem]

protocol CanvasItemStoreProtocol {
    var map: CanvasItemMap { get }
    var rootIds: [UUID] { get }
}

extension CanvasItemStoreProtocol {
    // MARK: queries

    func item(id: UUID) -> CanvasItem? {
        map.value(key: id)
    }

    func group(id: UUID) -> CanvasItemGroup? {
        item(id: id).map { if case let .group(group) = $0.kind { group } else { nil } }
    }

    var rootItems: [CanvasItem] {
        rootIds.compactMap { item(id: $0) }
    }

    func expanded(itemId: UUID) -> [CanvasItem] {
        guard let item = item(id: itemId) else { return [] }
        switch item.kind {
        case .path: return [item]
        case let .group(group): return [item] + group.members.flatMap { expanded(itemId: $0) }
        }
    }

    var allExpandedItems: [CanvasItem] {
        rootIds.flatMap { expanded(itemId: $0) }
    }

    var allGroups: [CanvasItemGroup] {
        allExpandedItems.compactMap { if case let .group(group) = $0.kind { group } else { nil }}
    }

    var allPathIds: [UUID] {
        allExpandedItems.compactMap { if case let .path(id) = $0.kind { id } else { nil }}
    }
}

// MARK: - CanvasItemStore

class CanvasItemStore: Store, CanvasItemStoreProtocol {
    @Trackable var map = CanvasItemMap()
    @Trackable var rootIds: [UUID] = []

    fileprivate func update(map: CanvasItemMap) {
        update { $0(\._map, map) }
    }

    fileprivate func update(rootIds: [UUID]) {
        update { $0(\._rootIds, rootIds) }
    }
}

// MARK: - PendingCanvasItemStore

class PendingCanvasItemStore: Store, CanvasItemStoreProtocol {
    @Trackable var map = CanvasItemMap()
    @Trackable var rootIds: [UUID] = []
    @Trackable fileprivate var active: Bool = false

    fileprivate func update(map: CanvasItemMap) {
        update { $0(\._map, map) }
    }

    fileprivate func update(rootIds: [UUID]) {
        update { $0(\._rootIds, rootIds) }
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
    var rootIds: [UUID] { pendingStore.active ? pendingStore.rootIds : store.rootIds }

    var allPaths: [Path] { allPathIds.compactMap { pathService.path(id: $0) } }

    // MARK: load document

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
            pendingStore.update(rootIds: store.rootIds)
            loadEvent(event)
        }
    }
}

// MARK: - modify item map

extension CanvasItemService {
    private func update(map: CanvasItemMap) {
        if pendingStore.active {
            pendingStore.update(map: map)
        } else {
            store.update(map: map)
        }
    }

    private func update(rootIds: [UUID]) {
        if pendingStore.active {
            pendingStore.update(rootIds: rootIds)
        } else {
            store.update(rootIds: rootIds)
        }
    }

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
        update(rootIds: .init())
    }
}

// MARK: - event loaders

extension CanvasItemService {
    private func loadEvent(_ event: DocumentEvent) {
        let _r = subtracer.range("load document event \(event.id)", type: .intent); defer { _r() }
        switch event.kind {
        case let .pathEvent(event): loadEvent(event)
        case let .compoundEvent(event): loadEvent(event)
        case let .itemEvent(event): loadEvent(event)
        }
    }

    private func loadEvent(_ event: CompoundEvent) {
        event.events.forEach {
            switch $0 {
            case let .pathEvent(event): loadEvent(event)
            case let .itemEvent(event): loadEvent(event)
            }
        }
    }

    // MARK: path event

    private func loadEvent(_ event: PathEvent) {
        let _r = subtracer.range("load event"); defer { _r() }
        switch event {
        case let .create(event):
            loadAffectedPaths(event.path.id)
        case let .delete(event):
            loadAffectedPaths(event.pathId)
        case let .update(event):
            loadAffectedPaths(event.pathId)
        case let .compound(event):
            loadEvent(event)
        }
    }

    private func loadEvent(_ event: PathEvent.Compound) {
        switch event {
        case let .merge(event):
            loadAffectedPaths(event.pathId, event.mergedPathId)
        case let .nodeBreak(event):
            loadAffectedPaths(event.pathId, event.newPathId)
        case let .edgeBreak(event):
            loadAffectedPaths(event.pathId, event.newPathId)
        }
    }

    private func loadAffectedPaths(_ pathIds: UUID...) {
        for pathId in pathIds {
            if pathService.path(id: pathId) == nil {
                remove(itemId: pathId)
                update(rootIds: rootIds.filter { $0 != pathId })
            } else if item(id: pathId) == nil {
                add(item: .init(kind: .path(pathId)))
                update(rootIds: rootIds + [pathId])
            }
        }
    }

    // MARK: item event

    private func loadEvent(_ event: ItemEvent) {
        switch event {
        case let .setMembers(event): loadEvent(event)
        }
    }

    private func loadEvent(_ event: ItemEvent.SetMembers) {
        let members = event.members, inGroupId = event.inGroupId
        if let inGroupId {
            if members.isEmpty {
                remove(itemId: inGroupId)
            } else if item(id: inGroupId) == nil {
                add(item: .init(kind: .group(.init(id: inGroupId, members: members))))
            } else {
                update(item: .init(kind: .group(.init(id: inGroupId, members: members))))
            }
        } else {
            update(rootIds: members)
        }
    }
}
