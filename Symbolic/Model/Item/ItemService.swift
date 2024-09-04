import Foundation

private let subtracer = tracer.tagged("ItemService")

typealias ItemMap = [UUID: Item]

typealias ItemParentMap = [UUID: UUID]
typealias ItemAncestorMap = [UUID: [UUID]]
typealias SymbolItemMap = [UUID: [Item]]
typealias ItemSymbolMap = [UUID: UUID]
typealias ItemDepthMap = [UUID: Int]

// MARK: - ItemStoreProtocol

protocol ItemStoreProtocol {
    var itemMap: ItemMap { get }

    var symbolIds: Set<UUID> { get }
    var itemAncestorMap: ItemAncestorMap { get }
    var symbolItemMap: SymbolItemMap { get }
    var itemSymbolMap: ItemSymbolMap { get }
    var itemDepthMap: ItemDepthMap { get }
}

extension ItemStoreProtocol {
    // MARK: simple selectors

    func get(id: UUID) -> Item? {
        itemMap.get(id)
    }

    func exists(id: UUID) -> Bool {
        get(id: id) != nil
    }

    func group(id: UUID) -> Item.Group? {
        get(id: id)?.group
    }

    func symbol(id: UUID) -> Item.Symbol? {
        get(id: id)?.symbol
    }

    // MARK: derived selectors

    var allSymbols: [Item.Symbol] {
        symbolIds.compactMap { symbol(id: $0) }
    }

    func ancestorIds(of itemId: UUID) -> [UUID] {
        itemAncestorMap[itemId] ?? []
    }

    func parentId(of itemId: UUID) -> UUID? {
        itemAncestorMap[itemId]?.first
    }

    func parent(of itemId: UUID) -> Item.Group? {
        parentId(of: itemId).map { group(id: $0) }
    }

    func symbolId(of itemId: UUID) -> UUID? {
        itemSymbolMap[itemId]
    }

    func symbol(of itemId: UUID) -> Item.Symbol? {
        symbolId(of: itemId).map { symbol(id: $0) }
    }

    func depth(of itemId: UUID) -> Int {
        itemDepthMap[itemId] ?? 0
    }

    // MARK: tree selectors

    func height(of itemId: UUID) -> Int {
        guard let item = get(id: itemId) else { return 0 }
        guard let group = item.group else { return 0 }
        return 1 + group.members.map { height(of: $0) }.max()!
    }

    func commonAncestorId(of itemIds: [UUID]) -> UUID? {
        let ancestorLists = itemIds.map { ancestorIds(of: $0) }
        let highest = ancestorLists.min { $0.count < $1.count }
        guard let highest, !highest.isEmpty else { return nil }

        let ancestorSets = itemIds.map { Set(ancestorIds(of: $0)) }
        return highest.first { id in ancestorSets.allSatisfy { $0.contains(id) } }
    }

    func expandedItems(rootId: UUID) -> [Item] {
        guard let item = get(id: rootId) else { return [] }
        guard let group = item.group else { return [item] }
        return [item] + group.members.flatMap { expandedItems(rootId: $0) }
    }

    func groupItems(rootId: UUID) -> [Item] {
        guard let item = get(id: rootId) else { return [] }
        guard let group = item.group else { return [] }
        return [item] + group.members.flatMap { groupItems(rootId: $0) }
    }

    func leafItems(rootId: UUID) -> [Item] {
        guard let item = get(id: rootId) else { return [] }
        guard let group = item.group else { return [item] }
        return group.members.flatMap { leafItems(rootId: $0) }
    }

    // MARK: symbol selectors

    func rootItems(symbolId: UUID) -> [Item] {
        symbol(id: symbolId)?.members.compactMap { get(id: $0) } ?? []
    }

    func allItems(symbolId: UUID) -> [Item] {
        symbolItemMap[symbolId] ?? []
    }

    func allExpandedItems(symbolId: UUID) -> [Item] {
        symbol(id: symbolId)?.members.flatMap { expandedItems(rootId: $0) } ?? []
    }

    func allGroups(symbolId: UUID) -> [Item.Group] {
        symbol(id: symbolId)?.members.flatMap { groupItems(rootId: $0) }.compactMap { $0.group } ?? []
    }

    func allPathItems(symbolId: UUID) -> [Item.Path] {
        symbol(id: symbolId)?.members.flatMap { leafItems(rootId: $0) }.compactMap { $0.path } ?? []
    }
}

// MARK: - ItemStore

class ItemStore: Store, ItemStoreProtocol {
    @Trackable var itemMap = ItemMap()

    @Derived({ $0.deriveSymbolIds }) var symbolIds: Set<UUID>
    @Derived({ $0.deriveItemAncestorMap }) var itemAncestorMap
    @Derived({ $0.deriveSymbolItemMap }) var symbolItemMap
    @Derived({ $0.deriveItemSymbolMap }) var itemSymbolMap
    @Derived({ $0.deriveItemDepthMap }) var itemDepthMap
}

// MARK: derived

extension ItemStore {
    private var deriveSymbolIds: Set<UUID> {
        .init(itemMap.values.compactMap { $0.symbol?.id })
    }

    private var deriveItemParentMap: ItemParentMap {
        symbolIds
            .flatMap { allGroups(symbolId: $0) }
            .reduce(into: ItemParentMap()) { dict, group in
                for member in group.members {
                    dict[member] = group.id
                }
            }
    }

    private var deriveItemAncestorMap: ItemAncestorMap {
        let parentMap = deriveItemParentMap
        return parentMap.reduce(into: ItemAncestorMap()) { dict, pair in
            let (id, parentId) = pair
            var ancestors: [UUID] = []
            var current: UUID? = parentId
            while let currentId = current {
                if let cached = dict[currentId] {
                    ancestors += [currentId] + cached
                    break
                } else {
                    ancestors.append(currentId)
                    current = parentMap[currentId]
                }
            }
            dict[id] = ancestors
        }
    }

    private var deriveSymbolItemMap: SymbolItemMap {
        symbolIds.reduce(into: SymbolItemMap()) { dict, symbolId in
            dict[symbolId] = allExpandedItems(symbolId: symbolId)
        }
    }

    private var deriveItemSymbolMap: ItemSymbolMap {
        symbolItemMap.reduce(into: ItemSymbolMap()) { dict, pair in
            let (symbolId, items) = pair
            for item in items {
                dict[item.id] = symbolId
            }
        }
    }

    private var deriveItemDepthMap: ItemDepthMap {
        itemMap.keys.reduce(into: ItemDepthMap()) { dict, itemId in
            dict[itemId] = ancestorIds(of: itemId).count
        }
    }
}

private extension ItemStore {
    func update(itemMap: ItemMap) {
        update { $0(\._itemMap, itemMap) }
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
    let store: ItemStore
    let pendingStore: PendingItemStore
    let path: PathService
    let viewport: ViewportService
}

// MARK: selectors

extension ItemService: ItemStoreProtocol {
    private var activeStore: ItemStore { pendingStore.active ? pendingStore : store }

    var itemMap: ItemMap { activeStore.itemMap }

    var symbolIds: Set<UUID> { activeStore.symbolIds }
    var itemAncestorMap: ItemAncestorMap { activeStore.itemAncestorMap }
    var symbolItemMap: SymbolItemMap { activeStore.symbolItemMap }
    var itemSymbolMap: ItemSymbolMap { activeStore.itemSymbolMap }
    var itemDepthMap: ItemDepthMap { activeStore.itemDepthMap }

    func allPaths(symbolId: UUID) -> [Path] {
        allPathItems(symbolId: symbolId).compactMap { path.pathMap.get($0.id) }
    }

    func allPathsBounds(symbolId: UUID) -> CGRect? {
        .init(union: allPaths(symbolId: symbolId).map { $0.boundingRect })
    }

    func groupedPathIds(groupId: UUID) -> [UUID] {
        leafItems(rootId: groupId).compactMap { $0.path?.id }
    }

    func boundingRect(of itemId: UUID) -> CGRect? {
        let itemMap = itemMap,
            pathMap = path.pathMap
        guard let item = itemMap.get(itemId) else { return nil }
        if let pathId = item.path?.id {
            return pathMap.get(pathId)?.boundingRect
        }
        if let group = item.group {
            let rects = group.members
                .compactMap { self.get(id: $0) }
                .compactMap { self.boundingRect(of: $0.id) }
            return .init(union: rects)
        }
        return nil
    }
}

// MARK: load document

extension ItemService {
    func load(document: Document) {
        let _r = subtracer.range(type: .intent, "load document, size=\(document.events.count)"); defer { _r() }
        withStoreUpdating {
            clear()
            for event in document.events {
                load(event: event)
            }
        }
    }

    func load(pendingEvent: DocumentEvent?) {
        if let pendingEvent {
            let _r = subtracer.range("load pending event \(pendingEvent.id)"); defer { _r() }
            withStoreUpdating {
                pendingStore.update(active: true)
                pendingStore.update(itemMap: store.itemMap)
                load(event: pendingEvent)
            }
        } else {
            let _r = subtracer.range("clear pending event"); defer { _r() }
            pendingStore.update(active: false)
        }
    }
}

// MARK: - modify

private extension ItemService {
    func add(item: Item) {
        let _r = subtracer.range("add \(item)"); defer { _r() }
        guard !exists(id: item.id) else { return }
        activeStore.update(itemMap: itemMap.cloned { $0[item.id] = item })
    }

    func update(item: Item) {
        let _r = subtracer.range("update \(item)"); defer { _r() }
        guard exists(id: item.id) else { return }
        activeStore.update(itemMap: itemMap.cloned { $0[item.id] = item })
    }

    func remove(itemIds: [UUID]) {
        let _r = subtracer.range("remove \(itemIds)"); defer { _r() }
        var itemMap = itemMap
        for itemId in itemIds {
            guard exists(id: itemId) else { continue }
            itemMap.removeValue(forKey: itemId)
        }
        activeStore.update(itemMap: itemMap)
    }

    func add(member newItemId: UUID, nextTo itemId: UUID) {
        let _r = subtracer.range("add member \(newItemId) next to \(itemId)"); defer { _r() }
        var itemMap = itemMap
        if var group = parent(of: itemId) {
            guard let index = group.members.firstIndex(of: itemId) else { return }
            let nextIndex = group.members.index(after: index)
            group.members.insert(newItemId, at: nextIndex)
            itemMap[group.id] = .init(kind: .group(group))
        } else if var symbol = symbol(of: itemId) {
            guard let index = symbol.members.firstIndex(of: itemId) else { return }
            let nextIndex = symbol.members.index(after: index)
            symbol.members.insert(newItemId, at: nextIndex)
            itemMap[symbol.id] = .init(kind: .symbol(symbol))
        }
        activeStore.update(itemMap: itemMap)
    }

    func remove(members itemIds: [UUID]) {
        let _r = subtracer.range("remove members \(itemIds)"); defer { _r() }
        var itemMap = itemMap
        for itemId in itemIds {
            if let groupId = parentId(of: itemId) {
                itemMap[groupId]?.group?.members.removeAll { $0 == itemId }
            } else if let symbolId = symbolId(of: itemId) {
                itemMap[symbolId]?.symbol?.members.removeAll { $0 == itemId }
            }
        }
        activeStore.update(itemMap: itemMap)
    }

    func clear() {
        let _r = subtracer.range("clear"); defer { _r() }
        activeStore.update(itemMap: .init())
    }
}

// MARK: - load event

private extension ItemService {
    func load(event: DocumentEvent) {
        let _r = subtracer.range(type: .intent, "load document event \(event.id)"); defer { _r() }
        switch event.kind {
        case let .compound(event):
            event.events.forEach { load(event: $0) }
        case let .single(event):
            load(event: event)
        }
    }

    func load(event: DocumentEvent.Single) {
        switch event {
        case let .path(event): load(event: event)
        case let .symbol(event): load(event: event)
        case let .item(event): load(event: event)
        }
    }

    // MARK: load path event

    func load(event: PathEvent) {
        let pathIds = event.pathIds
        for kind in event.kinds {
            switch kind {
            case let .create(event): load(pathIds: pathIds, event)
            case let .merge(event): load(pathIds: pathIds, event)
            case let .split(event): load(pathIds: pathIds, event)
            case let .delete(event): load(pathIds: pathIds, event)
            default: break
            }
        }
    }

    func load(pathIds: [UUID], _: PathEvent.Create) {
        guard let pathId = pathIds.first else { return }
        add(item: .init(kind: .path(.init(id: pathId))))
    }

    func load(pathIds: [UUID], _: PathEvent.Delete) {
        remove(itemIds: pathIds)
        remove(members: pathIds)
    }

    func load(pathIds: [UUID], _ event: PathEvent.Merge) {
        let mergedPathId = event.mergedPathId
        guard let pathId = pathIds.first,
              pathId != mergedPathId,
              !path.exists(id: mergedPathId) else { return }
        remove(itemIds: [mergedPathId])
        remove(members: [mergedPathId])
    }

    func load(pathIds: [UUID], _ event: PathEvent.Split) {
        let newPathId = event.newPathId
        guard let pathId = pathIds.first,
              let newPathId,
              path.exists(id: newPathId) else { return }
        add(item: .init(kind: .path(.init(id: newPathId))))
        add(member: newPathId, nextTo: pathId)
    }

    // MARK: load symbol event

    func load(event: SymbolEvent) {
        let symbolIds = event.symbolIds
        for kind in event.kinds {
            switch kind {
            case let .create(event): load(symbolIds: symbolIds, event)
            case let .setMembers(event): load(symbolIds: symbolIds, event)
            case let .delete(event): load(symbolIds: symbolIds, event)
            default: break
            }
        }
    }

    func load(symbolIds: [UUID], _: SymbolEvent.Create) {
        guard let symbolId = symbolIds.first,
              symbol(id: symbolId) == nil else { return }
        add(item: .init(kind: .symbol(.init(id: symbolId, members: []))))
    }

    func load(symbolIds: [UUID], _ event: SymbolEvent.SetMembers) {
        let members = event.members
        guard let symbolId = symbolIds.first,
              var item = get(id: symbolId) else { return }
        item.symbol?.members = members
        update(item: item)
    }

    func load(symbolIds: [UUID], _: SymbolEvent.Delete) {
        remove(itemIds: symbolIds)
    }

    // MARK: load item event

    func load(event: ItemEvent) {
        let itemIds = event.itemIds
        for kind in event.kinds {
            switch kind {
            case let .setGroup(event): load(itemIds: itemIds, event: event)
            case let .setName(event): load(itemIds: itemIds, event: event)
            case let .setLocked(event): load(itemIds: itemIds, event: event)
            }
        }
    }

    func load(itemIds: [UUID], event: ItemEvent.SetGroup) {
        let members = event.members
        guard let groupId = itemIds.first else { return }
        if members.isEmpty {
            remove(itemIds: [groupId])
        } else if var item = get(id: groupId) {
            item.group?.members = members
            update(item: item)
        } else {
            add(item: .init(kind: .group(.init(id: groupId, members: members))))
        }
    }

    func load(itemIds: [UUID], event: ItemEvent.SetName) {
        let name = event.name
        guard let itemIds = itemIds.first,
              var item = get(id: itemIds) else { return }
        item.name = name
        update(item: item)
    }

    func load(itemIds: [UUID], event: ItemEvent.SetLocked) {
        let locked = event.locked
        for itemId in itemIds {
            guard var item = get(id: itemId) else { return }
            item.locked = locked
            update(item: item)
        }
    }
}
