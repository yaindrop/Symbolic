import Foundation

private let subtracer = tracer.tagged("ItemService")

typealias ItemMap = [UUID: Item]

protocol ItemStoreProtocol {
    var map: ItemMap { get }
    var rootIds: [UUID] { get }
}

extension ItemStoreProtocol {
    func item(id: UUID) -> Item? {
        map.value(key: id)
    }

    func group(id: UUID) -> ItemGroup? {
        item(id: id).map { $0.group }
    }

    var rootItems: [Item] {
        rootIds.compactMap { item(id: $0) }
    }

    func expandedItems(itemId: UUID) -> [Item] {
        guard let item = item(id: itemId) else { return [] }
        if let group = item.group {
            return [item] + group.members.flatMap { expandedItems(itemId: $0) }
        }
        return [item]
    }

    var allExpandedItems: [Item] {
        rootIds.flatMap { expandedItems(itemId: $0) }
    }

    var allGroups: [ItemGroup] {
        allExpandedItems.compactMap { $0.group }
    }

    var allPathIds: [UUID] {
        allExpandedItems.compactMap { $0.pathId }
    }

    var idToParentId: [UUID: UUID] {
        var result: [UUID: UUID] = [:]
        for group in allGroups {
            for member in group.members {
                result[member] = group.id
            }
        }
        return result
    }

    var idToAncestorIds: [UUID: [UUID]] {
        var result: [UUID: [UUID]] = [:]
        let idToParentId = idToParentId
        for (id, parentId) in idToParentId {
            var ancestors: [UUID] = []
            var currentId: UUID? = parentId
            while let ancestorId = currentId {
                ancestors.append(ancestorId)
                currentId = idToParentId[ancestorId]
            }
            result[id] = ancestors
        }
        return result
    }
}

// MARK: - ItemStore

class ItemStore: Store, ItemStoreProtocol {
    @Trackable var map = ItemMap()
    @Trackable var rootIds: [UUID] = []

    fileprivate func update(map: ItemMap) {
        update { $0(\._map, map) }
    }

    fileprivate func update(rootIds: [UUID]) {
        update { $0(\._rootIds, rootIds) }
    }
}

// MARK: - PendingItemStore

class PendingItemStore: Store, ItemStoreProtocol {
    @Trackable var map = ItemMap()
    @Trackable var rootIds: [UUID] = []
    @Trackable fileprivate var active: Bool = false

    fileprivate func update(map: ItemMap) {
        update { $0(\._map, map) }
    }

    fileprivate func update(rootIds: [UUID]) {
        update { $0(\._rootIds, rootIds) }
    }

    fileprivate func update(active: Bool) {
        update { $0(\._active, active) }
    }
}

// MARK: - ItemService

struct ItemService: ItemStoreProtocol {
    let pathService: PathService
    let store: ItemStore
    let pendingStore: PendingItemStore

    var map: ItemMap { pendingStore.active ? pendingStore.map : store.map }
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

extension ItemService {
    private func update(map: ItemMap) {
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

    private func add(item: Item) {
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

    private func update(item: Item) {
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

extension ItemService {
    private func loadEvent(_ event: DocumentEvent) {
        let _r = subtracer.range("load document event \(event.id)", type: .intent); defer { _r() }
        switch event.kind {
        case let .pathEvent(event): loadEvent(event)
        case let .compoundEvent(event): loadEvent(event)
        case let .itemEvent(event): loadEvent(event)
        }
    }

    private func loadEvent(_ event: CompoundEvent) {
        for item in event.events {
            switch item {
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
