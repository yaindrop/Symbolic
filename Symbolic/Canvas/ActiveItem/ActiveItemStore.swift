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
    let viewport: ViewportService
    let toolbar: ToolbarStore
    let item: ItemService
    let path: PathService
    let pathProperty: PathPropertyService
    let store: ActiveItemStore
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
        item.allPaths.filter { activeItemIds.contains($0.id) }
    }

    var activeGroups: [ItemGroup] {
        item.allGroups.filter { activeItemIds.contains($0.id) }
    }

    var selectedItems: [Item] {
        selectedItemIds.compactMap { item.get(id: $0) }
    }

    var selectionBounds: CGRect? {
        .init(union: selectedItemIds.compactMap { item.boundingRect(itemId: $0.id) })?
            .applying(viewport.toView)
            .outset(by: 12)
    }

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

    var focusedPathBounds: CGRect? {
        guard let focusedPath else { return nil }
        return boundingRect(itemId: focusedPath.id)
    }

    var focusedGroup: ItemGroup? {
        guard let focusedItemId else { return nil }
        return item.group(id: focusedItemId)
    }

    var focusedGroupBounds: CGRect? {
        guard let focusedGroup else { return nil }
        return boundingRect(itemId: focusedGroup.id)
    }

    func activeDescendants(groupId: UUID) -> [Item] {
        item.expandedItems(rootItemId: groupId)
            .filter { $0.id != groupId && store.activeItemIds.contains($0.id) }
    }

    func boundingRect(itemId: UUID) -> CGRect? {
        guard let item = item.get(id: itemId) else { return nil }
        if let pathId = item.pathId {
            guard let path = path.get(id: pathId) else { return nil }
            return path.boundingRect.applying(viewport.toView)
        }
        guard let group = item.group else { return nil }
        var outsetLevel = 1
        let minHeight = activeDescendants(groupId: group.id).map { self.item.height(itemId: $0.id) }.filter { $0 > 0 }.min()
        if let minHeight {
            let height = self.item.height(itemId: group.id)
            outsetLevel += height - minHeight
        }
        return self.item.boundingRect(itemId: group.id)?
            .applying(viewport.toView)
            .outset(by: 6 * Scalar(outsetLevel))
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
