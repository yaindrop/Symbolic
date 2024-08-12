import SwiftUI

private let subtracer = tracer.tagged("ActiveItemService")

// MARK: - ActiveItemStore

class ActiveItemStore: Store {
    @Trackable var activeItemIds = Set<UUID>()
    @Trackable var focusedItemId: UUID?
}

private extension ActiveItemStore {
    func update(active: Set<UUID>, focused: UUID? = nil) {
        withStoreUpdating(configs: .init(animation: .faster)) {
            update { $0(\._activeItemIds, active) }
            update { $0(\._focusedItemId, focused) }
        }
    }

    func update(select itemId: UUID) {
        withStoreUpdating(configs: .init(animation: .faster)) {
            update(active: activeItemIds.cloned { $0.insert(itemId) })
        }
    }

    func update(deselect itemIds: [UUID]) {
        withStoreUpdating(configs: .init(animation: .faster)) {
            update(active: activeItemIds.cloned { $0.subtract(itemIds) })
        }
    }
}

// MARK: - ActiveItemService

struct ActiveItemService {
    let store: ActiveItemStore
    let toolbar: ToolbarStore
    let item: ItemService
    let path: PathService
    let pathProperty: PathPropertyService
}

// MARK: selectors

extension ActiveItemService {
    var activeItemIds: Set<UUID> { store.activeItemIds }
    var focusedItemId: UUID? { store.focusedItemId }

    // MARK: active

    var activeItems: [Item] {
        activeItemIds.compactMap { item.get(id: $0) }
    }

    var activePathIds: [UUID] {
        activeItems.compactMap { $0.pathId }
    }

    var activeGroups: [ItemGroup] {
        activeItems.compactMap { $0.group }
    }

    // MARK: selected

    var selectedItemIds: Set<UUID> {
        guard store.focusedItemId == nil else { return [] }
        var result = Set(activeItemIds)
        for id in activeItemIds {
            result.subtract(item.ancestorIds(of: id))
        }
        return result
    }

    var selectedItems: [Item] {
        selectedItemIds.compactMap { item.get(id: $0) }
    }

    var selectedPathIds: [UUID] {
        selectedItems.compactMap { $0.pathId }
    }

    func selected(itemId: UUID) -> Bool {
        selectedItemIds.contains(itemId)
    }

    var selectionBounds: CGRect? {
        .init(union: selectedItemIds.compactMap { item.boundingRect(itemId: $0.id) })
    }

    var selectionOutset: Scalar { 12 }

    // MARK: focused

    var focusedItem: Item? {
        focusedItemId.map { item.get(id: $0) }
    }

    var focusedPathId: UUID? {
        focusedItem.map { $0.pathId }
    }

    var focusedPath: Path? {
        focusedPathId.map { path.get(id: $0) }
    }

    var focusedPathProperty: PathProperty? {
        focusedItemId.map { pathProperty.get(id: $0) }
    }

    var focusedGroup: ItemGroup? {
        focusedItemId.map { item.group(id: $0) }
    }

    // MARK: group

    func activeDescendants(groupId: UUID) -> [Item] {
        item.expandedItems(rootItemId: groupId)
            .filter { $0.id != groupId && store.activeItemIds.contains($0.id) }
    }

    func groupOutset(id: UUID) -> Scalar {
        guard let group = item.group(id: id) else { return 0 }
        var outsetLevel = 1
        let minHeight = activeDescendants(groupId: group.id).map { self.item.height(itemId: $0.id) }.filter { $0 > 0 }.min()
        if let minHeight {
            let height = item.height(itemId: group.id)
            outsetLevel += height - minHeight
        }
        return 6 * Scalar(outsetLevel)
    }
}

// MARK: actions

extension ActiveItemService {
    // MARK: focus

    func focus(itemId: UUID) {
        let _r = subtracer.range(type: .intent, "focus \(itemId)"); defer { _r() }
        let ancestors = item.ancestorIds(of: itemId)
        if ancestors.isEmpty {
            store.update(active: [itemId], focused: itemId)
            return
        }
        let lastInactiveIndex = ancestors.lastIndex { !store.activeItemIds.contains($0) }
        if let lastInactiveIndex {
            store.update(active: .init(ancestors[lastInactiveIndex...]), focused: ancestors[lastInactiveIndex])
        } else {
            store.update(active: .init([itemId] + ancestors), focused: itemId)
        }
    }

    func blur() {
        let _r = subtracer.range(type: .intent, "blur"); defer { _r() }
        guard let focusedItemId = store.focusedItemId else {
            store.update(active: .init())
            return
        }

        let activeItemIds = store.activeItemIds.cloned { $0.remove(focusedItemId) }
        let parentId = item.parentId(of: focusedItemId)
        store.update(active: activeItemIds, focused: parentId)
    }

    // MARK: select

    func select(itemIds: [UUID]) {
        let _r = subtracer.range(type: .intent, "select \(itemIds)"); defer { _r() }
        store.update(active: .init(itemIds))
    }

    func selectAdd(itemId: UUID) {
        let _r = subtracer.range(type: .intent, "select \(item)"); defer { _r() }
        let ancestors = item.ancestorIds(of: itemId)
        if ancestors.isEmpty {
            store.update(active: store.activeItemIds.cloned { $0.insert(itemId) })
            return
        }
        let lastInactiveIndex = ancestors.lastIndex { !store.activeItemIds.contains($0) }
        if let lastInactiveIndex {
            store.update(select: ancestors[lastInactiveIndex])

        } else {
            store.update(select: itemId)
        }
    }

    func selectRemove(itemIds: [UUID]) {
        let _r = subtracer.range(type: .intent, "deselect \(itemIds)"); defer { _r() }
        store.update(deselect: itemIds)
    }
}
