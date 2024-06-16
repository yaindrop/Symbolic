import Foundation

private let subtracer = tracer.tagged("ItemService")

typealias ItemMap = [UUID: Item]
typealias AncestorMap = [UUID: [UUID]]

// MARK: - ItemStoreProtocol

protocol ItemStoreProtocol {
    var map: ItemMap { get }
    var rootIds: [UUID] { get }
    var ancestorMap: AncestorMap { get }
}

extension ItemStoreProtocol {
    func get(id: UUID) -> Item? {
        map.value(key: id)
    }

    func exists(id: UUID) -> Bool {
        get(id: id) != nil
    }

    func ancestorIds(of itemId: UUID) -> [UUID] {
        ancestorMap[itemId] ?? []
    }

    func parentId(of itemId: UUID) -> UUID? {
        ancestorMap[itemId]?.first
    }

    func commonAncestorId(itemIds: [UUID]) -> UUID? {
        let ancestorLists = itemIds.map { ancestorIds(of: $0) }
        let highest = ancestorLists.min { $0.count < $1.count }
        guard let highest, !highest.isEmpty else { return nil }

        let ancestorSets = itemIds.map { Set(ancestorIds(of: $0)) }
        return highest.first { id in ancestorSets.allSatisfy { $0.contains(id) } }
    }

    func group(id: UUID) -> ItemGroup? {
        get(id: id).map { $0.group }
    }

    var rootItems: [Item] {
        rootIds.compactMap { get(id: $0) }
    }

    func height(itemId: UUID) -> Int {
        guard let item = get(id: itemId) else { return 0 }
        guard let group = item.group else { return 0 }
        return 1 + group.members.map { height(itemId: $0) }.max()!
    }

    func depth(itemId: UUID) -> Int {
        ancestorIds(of: itemId).count
    }

    func expandedItems(rootItemId: UUID) -> [Item] {
        guard let item = get(id: rootItemId) else { return [] }
        guard let group = item.group else { return [item] }
        return [item] + group.members.flatMap { expandedItems(rootItemId: $0) }
    }

    func groupItems(rootItemId: UUID) -> [Item] {
        guard let item = get(id: rootItemId) else { return [] }
        guard let group = item.group else { return [] }
        return [item] + group.members.flatMap { groupItems(rootItemId: $0) }
    }

    func leafItems(rootItemId: UUID) -> [Item] {
        guard let item = get(id: rootItemId) else { return [] }
        guard let group = item.group else { return [item] }
        return group.members.flatMap { leafItems(rootItemId: $0) }
    }

    var allExpandedItems: [Item] {
        rootIds.flatMap { expandedItems(rootItemId: $0) }
    }

    var allGroups: [ItemGroup] {
        rootIds.flatMap { groupItems(rootItemId: $0) }.compactMap { $0.group }
    }

    var allPathIds: [UUID] {
        rootIds.flatMap { leafItems(rootItemId: $0) }.compactMap { $0.pathId }
    }

    private var idToParentId: [UUID: UUID] {
        allGroups.reduce(into: .init()) { dict, group in
            for member in group.members {
                dict[member] = group.id
            }
        }
    }

    fileprivate var idToAncestorIds: AncestorMap {
        idToParentId.reduce(into: [UUID: [UUID]]()) { dict, pair in
            let (id, parentId) = pair
            var ancestors: [UUID] = []
            var current: UUID? = parentId
            while let currentId = current {
                if let cached = dict[currentId] {
                    ancestors += [currentId] + cached
                    break
                } else {
                    ancestors.append(currentId)
                    current = idToParentId[currentId]
                }
            }
            dict[id] = ancestors
        }
    }
}

// MARK: - ItemStore

class ItemStore: Store, ItemStoreProtocol {
    @Trackable var map = ItemMap()
    @Trackable var rootIds: [UUID] = []

    @Derived({ $0.idToAncestorIds }) var ancestorMap
}

private extension ItemStore {
    func update(map: ItemMap) {
        update { $0(\._map, map) }
    }

    func update(rootIds: [UUID]) {
        update { $0(\._rootIds, rootIds) }
    }
}

// MARK: - PendingItemStore

class PendingItemStore: ItemStore {
    @Trackable fileprivate var active: Bool = false
}

private extension PendingItemStore {
    func update(active: Bool) {
        update { $0(\._active, active) }
    }
}

// MARK: - ItemService

struct ItemService {
    let path: PathService
    let store: ItemStore
    let pendingStore: PendingItemStore
}

// MARK: selectors

extension ItemService: ItemStoreProtocol {
    var map: ItemMap { pendingStore.active ? pendingStore.map : store.map }
    var rootIds: [UUID] { pendingStore.active ? pendingStore.rootIds : store.rootIds }
    var ancestorMap: AncestorMap { pendingStore.active ? pendingStore.ancestorMap : store.ancestorMap }

    var allPaths: [Path] { allPathIds.compactMap { path.get(id: $0) } }

    func groupedPaths(groupId: UUID) -> [Path] {
        leafItems(rootItemId: groupId)
            .compactMap { $0.pathId.map { path.get(id: $0) } }
    }

    func boundingRect(itemId: UUID) -> CGRect? {
        guard let item = get(id: itemId) else { return nil }
        if let pathId = item.pathId {
            return path.get(id: pathId)?.boundingRect
        }
        if let group = item.group {
            let rects = group.members
                .compactMap { self.get(id: $0) }
                .compactMap { self.boundingRect(itemId: $0.id) }
            return .init(union: rects)
        }
        return nil
    }
}

// MARK: - modify item map

extension ItemService {
    var targetStore: ItemStore { pendingStore.active ? pendingStore : store }

    private func add(item: Item) {
        let _r = subtracer.range("add"); defer { _r() }
        guard !exists(id: item.id) else { return }
        if case let .path(path) = item.kind {
            guard self.path.exists(id: path.id) else { return }
        }
        targetStore.update(map: map.cloned { $0[item.id] = item })
    }

    private func remove(itemId: UUID) {
        let _r = subtracer.range("remove"); defer { _r() }
        guard let item = get(id: itemId) else { return }
        if case let .path(path) = item.kind {
            guard !self.path.exists(id: path.id) else { return }
        }
        targetStore.update(map: map.cloned { $0.removeValue(forKey: itemId) })
    }

    private func update(item: Item) {
        let _r = subtracer.range("update"); defer { _r() }
        guard exists(id: item.id) else { return }
        if case let .path(path) = item.kind {
            guard self.path.exists(id: path.id) else { remove(itemId: item.id); return }
        }
        targetStore.update(map: map.cloned { $0[item.id] = item })
    }

    private func clear() {
        let _r = subtracer.range("clear"); defer { _r() }
        targetStore.update(map: .init())
        targetStore.update(rootIds: .init())
    }
}

// MARK: load document

extension ItemService {
    func loadDocument(_ document: Document) {
        let _r = subtracer.range(type: .intent, "load document, size=\(document.events.count)"); defer { _r() }
        withStoreUpdating {
            clear()
            for event in document.events {
                loadEvent(event)
            }
        }
    }

    func loadPendingEvent(_ event: DocumentEvent?) {
        let _r = subtracer.range("load pending event"); defer { _r() }
        withStoreUpdating {
            if let event {
                pendingStore.update(active: true)
                pendingStore.update(map: store.map.cloned)
                pendingStore.update(rootIds: store.rootIds)
                loadEvent(event)
            } else {
                pendingStore.update(active: false)
            }
        }
    }
}

// MARK: - event loaders

extension ItemService {
    private func loadEvent(_ event: DocumentEvent) {
        let _r = subtracer.range(type: .intent, "load document event \(event.id)"); defer { _r() }
        switch event.kind {
        case let .compound(event):
            event.events.forEach { loadEvent($0) }
        case let .single(event):
            loadEvent(event)
        }
    }

    private func loadEvent(_ event: SingleEvent) {
        switch event {
        case let .item(event): loadEvent(event)
        case let .path(event): loadEvent(event)
        case .pathProperty: break
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
            } else if get(id: inGroupId) == nil {
                add(item: .init(kind: .group(.init(id: inGroupId, members: members))))
            } else {
                update(item: .init(kind: .group(.init(id: inGroupId, members: members))))
            }
        } else {
            targetStore.update(rootIds: members)
        }
    }

    // MARK: path event

    private func loadEvent(_ event: PathEvent) {
        for pathId in event.affectedPathIds {
            let item = get(id: pathId)
            let path = path.get(id: pathId)
            if path == nil {
                guard item?.pathId != nil else { continue }
                remove(itemId: pathId)
                targetStore.update(rootIds: rootIds.filter { $0 != pathId })
            } else if item == nil {
                add(item: .init(kind: .path(pathId)))
                targetStore.update(rootIds: rootIds + [pathId])
            }
        }
    }
}
