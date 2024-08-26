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

    func group(id: UUID) -> ItemGroup? {
        get(id: id)?.group
    }

    func symbol(id: UUID) -> ItemSymbol? {
        get(id: id)?.symbol
    }

    func rootItems(symbolId: UUID) -> [Item] {
        symbol(id: symbolId)?.members.compactMap { get(id: $0) } ?? []
    }

    func ancestorIds(of itemId: UUID) -> [UUID] {
        itemAncestorMap[itemId] ?? []
    }

    func parentId(of itemId: UUID) -> UUID? {
        itemAncestorMap[itemId]?.first
    }

    func allItems(symbolId: UUID) -> [Item] {
        symbolItemMap[symbolId] ?? []
    }

    func symbolId(of itemId: UUID) -> UUID? {
        itemSymbolMap[itemId]
    }

    func depth(of itemId: UUID) -> Int {
        itemDepthMap[itemId] ?? 0
    }

    // MARK: complex selectors

    func commonAncestorId(itemIds: [UUID]) -> UUID? {
        let ancestorLists = itemIds.map { ancestorIds(of: $0) }
        let highest = ancestorLists.min { $0.count < $1.count }
        guard let highest, !highest.isEmpty else { return nil }

        let ancestorSets = itemIds.map { Set(ancestorIds(of: $0)) }
        return highest.first { id in ancestorSets.allSatisfy { $0.contains(id) } }
    }

    func height(itemId: UUID) -> Int {
        guard let item = get(id: itemId) else { return 0 }
        guard let group = item.group else { return 0 }
        return 1 + group.members.map { height(itemId: $0) }.max()!
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

    func allExpandedItems(symbolId: UUID) -> [Item] {
        symbol(id: symbolId)?.members.flatMap { expandedItems(rootItemId: $0) } ?? []
    }

    func allGroups(symbolId: UUID) -> [ItemGroup] {
        symbol(id: symbolId)?.members.flatMap { groupItems(rootItemId: $0) }.compactMap { $0.group } ?? []
    }

    func allPaths(symbolId: UUID) -> [ItemPath] {
        symbol(id: symbolId)?.members.flatMap { leafItems(rootItemId: $0) }.compactMap { $0.path } ?? []
    }
}

private extension ItemStoreProtocol {
    var calcSymbolIds: Set<UUID> {
        .init(itemMap.values.compactMap { $0.symbol?.id })
    }

    private var calcItemParentMap: ItemParentMap {
        symbolIds
            .flatMap { allGroups(symbolId: $0) }
            .reduce(into: ItemParentMap()) { dict, group in
                for member in group.members {
                    dict[member] = group.id
                }
            }
    }

    var calcItemAncestorMap: ItemAncestorMap {
        let parentMap = calcItemParentMap
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

    var calcSymbolItemMap: SymbolItemMap {
        symbolIds.reduce(into: SymbolItemMap()) { dict, symbolId in
            dict[symbolId] = allExpandedItems(symbolId: symbolId)
        }
    }

    var calcItemSymbolMap: ItemSymbolMap {
        symbolItemMap.reduce(into: ItemSymbolMap()) { dict, pair in
            let (symbolId, items) = pair
            for item in items {
                dict[item.id] = symbolId
            }
        }
    }

    var calcItemDepthMap: ItemDepthMap {
        itemMap.keys.reduce(into: ItemDepthMap()) { dict, itemId in
            dict[itemId] = ancestorIds(of: itemId).count
        }
    }
}

// MARK: - ItemStore

class ItemStore: Store, ItemStoreProtocol {
    @Trackable var itemMap = ItemMap()
//    @Trackable var symbolRootMap = SymbolRootMap()

    @Derived({ $0.calcSymbolIds }) var symbolIds: Set<UUID>
    @Derived({ $0.calcItemAncestorMap }) var itemAncestorMap
    @Derived({ $0.calcSymbolItemMap }) var symbolItemMap
    @Derived({ $0.calcItemSymbolMap }) var itemSymbolMap
    @Derived({ $0.calcItemDepthMap }) var itemDepthMap
}

private extension ItemStore {
    func update(itemMap: ItemMap) {
        update { $0(\._itemMap, itemMap) }
    }

//    func update(symbolRootMap: SymbolRootMap) {
//        update { $0(\._symbolRootMap, symbolRootMap) }
//    }
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
    let viewport: ViewportService
    let path: PathService
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
        let pathMap = path.pathMap
        return allPaths(symbolId: symbolId).compactMap { pathMap.get($0.id) }
    }

    func allPathsBounds(symbolId: UUID) -> CGRect? {
        .init(union: allPaths(symbolId: symbolId).map { $0.boundingRect })
    }

    func groupedPathIds(groupId: UUID) -> [UUID] {
        leafItems(rootItemId: groupId).compactMap { $0.path?.id }
    }

    func boundingRect(itemId: UUID) -> CGRect? {
        let itemMap = itemMap,
            pathMap = path.pathMap
        guard let item = itemMap.get(itemId) else { return nil }
        if let pathId = item.path?.id {
            return pathMap.get(pathId)?.boundingRect
        }
        if let group = item.group {
            let rects = group.members
                .compactMap { self.get(id: $0) }
                .compactMap { self.boundingRect(itemId: $0.id) }
            return .init(union: rects)
        }
        return nil
    }

    func symbolHitTest(position: Point2) -> UUID? {
        symbolIds.first {
            guard let symbol = self.symbol(id: $0) else { return false }
            return symbol.boundingRect.contains(position)
        }
    }

    func pathHitTest(pathId: UUID, path: Path, position: Point2, threshold: Scalar = 24) -> Bool {
        guard let symbolId = symbolId(of: pathId),
              let symbol = symbol(id: symbolId) else { return false }
        let worldToSymbol = symbol.worldToSymbol,
            viewToSymbol = viewport.viewToWorld.concatenating(worldToSymbol),
            symbolPosition = position.applying(worldToSymbol),
            width = (threshold * Vector2.unitX).applying(viewToSymbol).dx
        guard path.boundingRect.outset(by: width / 2).contains(symbolPosition) else { return false }
        return path.hitPath(width: width).contains(symbolPosition)
    }

    func pathHitTest(position: Point2, threshold _: Scalar = 24) -> UUID? {
        path.pathMap.first { pathId, path in pathHitTest(pathId: pathId, path: path, position: position) }?.key
    }
}

// MARK: - modify item map

private extension ItemService {
    func add(symbol: ItemSymbol) {
        let _r = subtracer.range("add symbol"); defer { _r() }
        guard !exists(id: symbol.id) else { return }

        var newItemMap = itemMap
        newItemMap[symbol.id] = .init(kind: .symbol(symbol))
        activeStore.update(itemMap: newItemMap)
    }

    func add(symbolId: UUID, item: Item) {
        let _r = subtracer.range("add"); defer { _r() }
        guard !exists(id: item.id),
              var symbol = get(id: symbolId)?.symbol else { return }
        if case let .path(path) = item.kind {
            guard self.path.exists(id: path.id) else { return }
        }
        symbol.members += [item.id]
        var newItemMap = itemMap
        newItemMap[item.id] = item
        newItemMap[symbolId] = .init(kind: .symbol(symbol))
        activeStore.update(itemMap: newItemMap)
    }

    func remove(itemId: UUID) {
        let _r = subtracer.range("remove"); defer { _r() }
        guard let item = get(id: itemId) else { return }
        if case let .path(path) = item.kind {
            guard !self.path.exists(id: path.id) else { return }
        }
        guard let symbolId = symbolId(of: itemId),
              var symbol = get(id: symbolId)?.symbol else { return }
        var newItemMap = itemMap
        if let parentId = parentId(of: itemId) {
            guard var group = group(id: parentId) else { return }
            group.members.removeAll { $0 == itemId }
            newItemMap[parentId] = .init(kind: .group(group))
        } else {
            symbol.members.removeAll { $0 == itemId }
            newItemMap[symbolId] = .init(kind: .symbol(symbol))
        }
        activeStore.update(itemMap: newItemMap)
    }

    func update(item: Item) {
        let _r = subtracer.range("update"); defer { _r() }
        guard exists(id: item.id) else { return }
        if case let .path(path) = item.kind {
            guard self.path.exists(id: path.id) else { remove(itemId: item.id); return }
        }
        var newItemMap = itemMap
        newItemMap[item.id] = item
        activeStore.update(itemMap: newItemMap)
    }

    func clear() {
        let _r = subtracer.range("clear"); defer { _r() }
        activeStore.update(itemMap: .init())
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
        let _r = subtracer.range("load pending event"); defer { _r() }
        withStoreUpdating {
            if let pendingEvent {
                pendingStore.update(active: true)
                pendingStore.update(itemMap: store.itemMap)
                load(event: pendingEvent)
            } else {
                pendingStore.update(active: false)
            }
        }
    }
}

// MARK: - event loaders

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
        case .pathProperty: break
        case let .item(event): load(event: event)
        }
    }

    // MARK: path event

    func load(event: PathEvent) {
        let affectedSymbolId = event.affectedSymbolId,
            affectedPathIds = event.affectedPathIds
        guard let symbolId = {
            if let id = affectedSymbolId {
                return id
            }
            for pathId in affectedPathIds {
                guard let id = symbolId(of: pathId) else { continue }
                return id
            }
            return nil
        }() else { return }
        for pathId in affectedPathIds {
            let item = get(id: pathId)
            let path = path.get(id: pathId)
            if path == nil {
                guard item?.path?.id != nil else { continue }
                remove(itemId: pathId)
            } else if item == nil {
                add(symbolId: symbolId, item: .init(kind: .path(.init(id: pathId))))
            }
        }
    }

    // MARK: item event

    func load(event: ItemEvent) {
        switch event {
        case let .setGroup(event): load(event: event)
        case let .setSymbol(event): load(event: event)
        case let .deleteSymbol(event): load(event: event)
        }
    }

    func load(event: ItemEvent.SetGroup) {
        let groupId = event.groupId,
            members = event.members
        guard let symbolId = members.compactMap({ symbolId(of: $0) }).allSame() else { return }
        if members.isEmpty {
            remove(itemId: groupId)
            return
        }
        let item: Item = .init(kind: .group(.init(id: groupId, members: members)))
        if get(id: groupId) == nil {
            add(symbolId: symbolId, item: item)
        } else {
            update(item: item)
        }
    }

    func load(event: ItemEvent.SetSymbol) {
        let symbolId = event.symbolId,
            origin = event.origin,
            size = event.size,
            members = event.members
        let symbol: ItemSymbol = .init(id: symbolId, origin: origin, size: size, members: members)
        if get(id: symbolId) == nil {
            add(symbol: symbol)
        } else {
            update(item: .init(kind: .symbol(symbol)))
        }
    }

    func load(event: ItemEvent.DeleteSymbol) {
        let symbolId = event.symbolId
        guard get(id: symbolId)?.symbol != nil else { return }
        remove(itemId: symbolId)
    }
}
