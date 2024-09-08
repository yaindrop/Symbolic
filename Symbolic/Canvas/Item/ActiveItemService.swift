import SwiftUI

private let subtracer = tracer.tagged("ActiveItemService")

// MARK: - ActiveItemStore

enum ItemActiveState: Equatable {
    case none
    case active(Set<UUID>)
    case focused(UUID)
}

class ActiveItemStore: Store {
    @Trackable var state: ItemActiveState = .none
}

private extension ActiveItemStore {
    func update(state: ItemActiveState) {
        withStoreUpdating(.animation(.faster)) {
            update { $0(\._state, state) }
        }
    }
}

// MARK: - ActiveItemService

struct ActiveItemService {
    let store: ActiveItemStore
    let toolbar: ToolbarStore
    let path: PathService
    let item: ItemService
}

// MARK: selectors

extension ActiveItemService {
    var state: ItemActiveState { store.state }

    var activeItemIds: Set<UUID> {
        switch state {
        case .none: []
        case let .active(ids): ids
        case let .focused(id): .init([id] + item.ancestorIds(of: id))
        }
    }

    var focusedItemId: UUID? { if case let .focused(id) = state { id } else { nil } }

    // MARK: active

    var activeItems: [Item] {
        activeItemIds.compactMap { item.get(id: $0) }
    }

    var activePathIds: [UUID] {
        activeItems.compactMap { $0.path?.id }
    }

    var activeGroups: [Item.Group] {
        activeItems.compactMap { $0.group }
    }

    // MARK: selection

    var selectedItemIds: Set<UUID> {
        guard focusedItemId == nil else { return [] }
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
        selectedItems.compactMap { $0.path?.id }
    }

    func selected(id: UUID) -> Bool {
        selectedItemIds.contains(id)
    }

    var selectionBounds: CGRect? {
        .init(union: selectedItemIds.compactMap { item.boundingRect(of: $0.id) })
    }

    static var selectionBoundsOutset: Scalar { 12 }

    var selectionLocked: Bool {
        selectedItemIds.compactMap { item.get(id: $0) }.allSatisfy { $0.locked }
    }

    // MARK: focused

    var focusedItem: Item? {
        focusedItemId.map { item.get(id: $0) }
    }

    var focusedPathId: UUID? {
        focusedItem?.path?.id
    }

    var focusedPathItem: Item? {
        guard let focusedItem,
              focusedItem.path != nil else { return nil }
        return focusedItem
    }

    var focusedPathBounds: CGRect? {
        focusedPathId.map { item.boundingRect(of: $0) }
    }

    var focusedPath: Path? {
        focusedPathId.map { path.get(id: $0) }
    }

    var focusedPathProperty: PathProperty? {
        focusedPathId.map { path.property(id: $0) }
    }

    var focusedGroupId: UUID? {
        focusedItem?.group?.id
    }

    var focusedGroupItem: Item? {
        guard let focusedItem,
              focusedItem.group != nil else { return nil }
        return focusedItem
    }

    var focusedGroupBounds: CGRect? {
        focusedGroupId.map { item.boundingRect(of: $0) }
    }

    var focusedGroupOutset: Scalar {
        focusedGroupId.map { groupOutset(id: $0) } ?? 0
    }

    // MARK: group

    func activeDescendants(groupId: UUID) -> [Item] {
        item.expandedItems(rootId: groupId)
            .filter { $0.id != groupId && activeItemIds.contains($0.id) }
    }

    func groupOutset(id: UUID) -> Scalar {
        guard let group = item.group(id: id) else { return 0 }
        var outsetLevel = 1
        let minHeight = activeDescendants(groupId: group.id).map { self.item.height(of: $0.id) }.filter { $0 > 0 }.min()
        if let minHeight {
            let height = item.height(of: group.id)
            outsetLevel += height - minHeight
        }
        return 6 * Scalar(outsetLevel)
    }
}

// MARK: actions

extension ActiveItemService {
    // MARK: focus

    func onTap(itemId: UUID?) {
        let _r = subtracer.range(type: .intent, "tap \(itemId?.shortDescription ?? "outside")"); defer { _r() }
        if let itemId {
            let ancestors = item.ancestorIds(of: itemId)
            if let index = ancestors.lastIndex(where: { !activeItemIds.contains($0) }) {
                store.update(state: .focused(ancestors[index]))
            } else {
                store.update(state: .focused(itemId))
            }
        } else {
            if let focusedItemId, let parentId = item.parentId(of: focusedItemId) {
                store.update(state: .focused(parentId))
            } else {
                store.update(state: .none)
            }
        }
    }

    func focus(itemId: UUID) {
        let _r = subtracer.range(type: .intent, "focus \(itemId)"); defer { _r() }
        store.update(state: .focused(itemId))
    }

    func blur() {
        let _r = subtracer.range(type: .intent, "blur"); defer { _r() }
        store.update(state: .none)
    }

    // MARK: select

    func select(itemIds: [UUID]) {
        let _r = subtracer.range(type: .intent, "select \(itemIds)"); defer { _r() }
        store.update(state: .active(.init(itemIds)))
    }

    func selectAdd(itemId: UUID) {
        let _r = subtracer.range(type: .intent, "select \(item)"); defer { _r() }
        let ancestors = item.ancestorIds(of: itemId)
        if ancestors.isEmpty {
            store.update(state: .active(activeItemIds.cloned { $0.insert(itemId) }))
            return
        }
        let lastInactiveIndex = ancestors.lastIndex { !activeItemIds.contains($0) }
        if let lastInactiveIndex {
            store.update(state: .active(activeItemIds.cloned { $0.insert(ancestors[lastInactiveIndex]) }))
        } else {
            store.update(state: .active(activeItemIds.cloned { $0.insert(itemId) }))
        }
    }

    func selectRemove(itemIds: [UUID]) {
        let _r = subtracer.range(type: .intent, "deselect \(itemIds)"); defer { _r() }
        store.update(state: .active(activeItemIds.cloned { $0.subtract(itemIds) }))
    }
}
