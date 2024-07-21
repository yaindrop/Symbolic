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

    var selectedItemIds: Set<UUID> {
        guard store.focusedItemId == nil else { return [] }
        var result = Set(store.activeItemIds)
        for id in store.activeItemIds {
            result.subtract(item.ancestorIds(of: id))
        }
        return result
    }

    var activePaths: [Path] {
        let activeItemIds = activeItemIds
        return item.allPaths.filter { activeItemIds.contains($0.id) }
    }

    var activeGroups: [ItemGroup] {
        let activeItemIds = activeItemIds
        return item.allGroups.filter { activeItemIds.contains($0.id) }
    }

    var selectedItems: [Item] {
        selectedItemIds.compactMap { item.get(id: $0) }
    }

    var selectionBounds: CGRect? {
        .init(union: selectedItemIds.compactMap { item.boundingRect(itemId: $0.id) })
    }

    var selectionOutset: Scalar { 12 }

    var selectedPaths: [Path] {
        selectedItemIds
            .flatMap { item.leafItems(rootItemId: $0) }
            .compactMap { path.get(id: $0.id) }
    }

    func selected(itemId: UUID) -> Bool {
        selectedItemIds.contains(itemId)
    }

    var focusedPath: Path? {
        guard let focusedItemId else { return nil }
        return path.get(id: focusedItemId)
    }

    var focusedPathProperty: PathProperty? {
        guard let focusedItemId else { return nil }
        return pathProperty.get(id: focusedItemId)
    }

    var focusedGroup: ItemGroup? {
        guard let focusedItemId else { return nil }
        return item.group(id: focusedItemId)
    }

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

// MARK: focus actions

extension ActiveItemService {
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
}

// MARK: select actions

extension ActiveItemService {
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
