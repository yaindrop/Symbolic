import SwiftUI

private let subtracer = tracer.tagged("ActiveItemService")

// MARK: - ActiveItemStore

enum ActiveItemState: Equatable {
    case none
    case active(Set<UUID>)
    case focused(UUID)
}

class ActiveItemStore: Store {
    @Trackable var state: ActiveItemState = .none
}

private extension ActiveItemStore {
    func update(state: ActiveItemState) {
        withStoreUpdating(configs: .init(animation: .faster)) {
            update { $0(\._state, state) }
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
    var state: ActiveItemState { store.state }

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
        activeItems.compactMap { $0.pathId }
    }

    var activeGroups: [ItemGroup] {
        activeItems.compactMap { $0.group }
    }

    // MARK: selected

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
            .filter { $0.id != groupId && activeItemIds.contains($0.id) }
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
        let ancestors = item.ancestorIds(of: itemId)
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
