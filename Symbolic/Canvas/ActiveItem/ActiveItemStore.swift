import Foundation
import SwiftUI

private let subtracer = tracer.tagged("ActiveItemService")

// MARK: - ActiveItemStore

class ActiveItemStore: Store {
    @Trackable var activeItemIds = Set<UUID>()
    @Trackable var focusedItemId: UUID?

    fileprivate func update(active: Set<UUID>, focused: UUID? = nil) {
        withFastAnimation {
            withStoreUpdating {
                update { $0(\._activeItemIds, active) }
                update { $0(\._focusedItemId, focused) }
            }
        }
    }

    fileprivate func update(select itemId: UUID) {
        withFastAnimation {
            update(active: activeItemIds.with { $0.insert(itemId) })
        }
    }

    fileprivate func update(deselect itemIds: [UUID]) {
        withFastAnimation {
            update(active: activeItemIds.with { $0.subtract(itemIds) })
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
        selectedItemIds.compactMap { item.item(id: $0) }
    }

    var selectionBounds: CGRect? {
        .init(union: selectedItemIds.compactMap { item.boundingRect(itemId: $0.id) })?
            .applying(viewport.toView)
            .outset(by: 12)
    }

    var selectedPaths: [Path] {
        selectedItemIds
            .flatMap { item.leafItems(rootItemId: $0) }
            .compactMap { path.path(id: $0.id) }
    }

    func selected(itemId: UUID) -> Bool {
        selectedItemIds.contains(itemId)
    }

    var focusedPath: Path? {
        if let focusedItemId {
            return path.path(id: focusedItemId)
        }
        return nil
    }

    var focusedPathProperty: PathProperty? {
        if let focusedItemId {
            return pathProperty.property(id: focusedItemId)
        }
        return nil
    }

    var focusedGroup: ItemGroup? {
        if let focusedItemId {
            return item.group(id: focusedItemId)
        }
        return nil
    }

    func activeDescendants(groupId: UUID) -> [Item] {
        item.expandedItems(rootItemId: groupId)
            .filter { $0.id != groupId && store.activeItemIds.contains($0.id) }
    }

    func boundingRect(itemId: UUID) -> CGRect? {
        guard let item = item.item(id: itemId) else { return nil }
        if let pathId = item.pathId {
            guard let path = path.path(id: pathId) else { return nil }
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

        let activeItemIds = store.activeItemIds.with { $0.remove(focusedItemId) }
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
            store.update(active: store.activeItemIds.with { $0.insert(itemId) })
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
