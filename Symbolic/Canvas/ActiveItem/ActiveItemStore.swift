import Foundation
import SwiftUI

private let subtracer = tracer.tagged("ActiveItemService")

// MARK: - PathFocusedPart

enum PathFocusedPart: Equatable {
    case node(UUID)
    case edge(UUID)

    var id: UUID {
        switch self {
        case let .node(id): id
        case let .edge(id): id
        }
    }

    var edgeId: UUID? {
        if case let .edge(id) = self { id } else { nil }
    }

    var nodeId: UUID? {
        if case let .node(id) = self { id } else { nil }
    }
}

// MARK: - ActiveItemStore

class ActiveItemStore: Store {
    @Trackable var activeItemIds = Set<UUID>()
    @Trackable var focusedItemId: UUID?

    @Trackable var pathFocusedPart: PathFocusedPart?

    fileprivate func update(active: Set<UUID>, focused: UUID? = nil) {
        withAnimation(.default.speed(5)) {
            withStoreUpdating {
                update { $0(\._activeItemIds, active) }
                update { $0(\._focusedItemId, focused) }
            }
        }
    }

    fileprivate func update(select itemId: UUID) {
        withAnimation(.default.speed(5)) {
            update(active: activeItemIds.with { $0.insert(itemId) })
        }
    }

    fileprivate func update(deselect itemIds: [UUID]) {
        withAnimation(.default.speed(5)) {
            update(active: activeItemIds.with { $0.subtract(itemIds) })
        }
    }

    fileprivate func update(pathFocusedPart: PathFocusedPart?) {
        withAnimation(.default.speed(5)) {
            update { $0(\._pathFocusedPart, pathFocusedPart) }
        }
    }
}

// MARK: - ActiveItemService

struct ActiveItemService {
    let item: ItemService
    let path: PathService
    let store: ActiveItemStore
}

// MARK: selectors

extension ActiveItemService {
    var activeItemIds: Set<UUID> { store.activeItemIds }
    var focusedItemId: UUID? { store.focusedItemId }
    var pathFocusedPart: PathFocusedPart? { store.pathFocusedPart }

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
        .init(union: selectedItems.compactMap { item.boundingRect(item: $0) })?
            .applying(global.viewport.toView)
            .outset(by: 12)
    }

    var selectedPaths: [Path] {
        selectedItemIds
            .flatMap { item.leafItems(rootItemId: $0) }
            .compactMap { path.path(id: $0.id) }
    }

    var activePath: Path? {
        if let focusedItemId {
            return path.map[focusedItemId]
        }
        return nil
    }
}

// MARK: focus actions

extension ActiveItemService {
    func focus(itemId: UUID) {
        let _r = subtracer.range("focus \(itemId)", type: .intent); defer { _r() }
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
        let _r = subtracer.range("blur", type: .intent); defer { _r() }
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
        let _r = subtracer.range("select \(itemIds)", type: .intent); defer { _r() }
        store.update(active: .init(itemIds))
    }

    func selectAdd(itemId: UUID) {
        let _r = subtracer.range("select \(item)", type: .intent); defer { _r() }
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
        let _r = subtracer.range("deselect \(itemIds)", type: .intent); defer { _r() }
        store.update(deselect: itemIds)
    }
}

// MARK: path part focus actions

extension ActiveItemService {
    func setFocus(node id: UUID) {
        let _r = subtracer.range("set focus", type: .intent); defer { _r() }
        store.update(pathFocusedPart: .node(id))
    }

    func setFocus(edge fromNodeId: UUID) {
        let _r = subtracer.range("set focus", type: .intent); defer { _r() }
        store.update(pathFocusedPart: .edge(fromNodeId))
    }

    func clearFocus() {
        let _r = subtracer.range("clear focus", type: .intent); defer { _r() }
        store.update(pathFocusedPart: nil)
    }

    func onActivePathChanged() {
        if let part = store.pathFocusedPart {
            if let path = activePath {
                if path.node(id: part.id) == nil {
                    clearFocus()
                }
            } else {
                clearFocus()
            }
        }
    }
}
