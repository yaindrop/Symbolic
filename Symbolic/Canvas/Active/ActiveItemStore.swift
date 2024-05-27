import Foundation
import SwiftUI

private let subtracer = tracer.tagged("ActivePathService")

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

// MARK: - ActivePathStore

class ActivePathStore: Store {
    @Trackable var activePathId: UUID?
    @Trackable var focusedPart: PathFocusedPart?

    fileprivate func update(activePathId: UUID?) {
        update {
            if activePathId == nil {
                $0(\._focusedPart, nil)
            }
            $0(\._activePathId, activePathId)
        }
    }

    fileprivate func update(focusedPart: PathFocusedPart?) {
        update { $0(\._focusedPart, focusedPart) }
    }
}

// MARK: - ActivePathService

struct ActivePathService {
    let path: PathService
    let store: ActivePathStore

    var activePathId: UUID? { store.activePathId }

    var activePath: Path? { path.map.first { id, _ in id == activePathId }?.value }

    var focusedPart: PathFocusedPart? { store.focusedPart }

    func activate(pathId: UUID) {
        store.update(activePathId: pathId)
    }

    func deactivate() {
        store.update(activePathId: nil)
    }

    func setFocus(node id: UUID) {
        let _r = subtracer.range("set focus", type: .intent); defer { _r() }
        withAnimation { store.update(focusedPart: .node(id)) }
    }

    func setFocus(edge fromNodeId: UUID) {
        let _r = subtracer.range("set focus", type: .intent); defer { _r() }
        withAnimation { store.update(focusedPart: .edge(fromNodeId)) }
    }

    func clearFocus() {
        let _r = subtracer.range("clear focus", type: .intent); defer { _r() }
        withAnimation { store.update(focusedPart: nil) }
    }

    func onActivePathChanged() {
        if let part = store.focusedPart {
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

// MARK: - ActivePathStore

class ActiveItemStore: Store {
    @Trackable var activeItemIds = Set<UUID>()
    @Trackable var focusedItemId: UUID?

    fileprivate func update(activeItemIds: Set<UUID>) {
        update { $0(\._activeItemIds, activeItemIds) }
    }

    fileprivate func update(focusedItemId: UUID?) {
        update { $0(\._focusedItemId, focusedItemId) }
    }
}

struct ActiveItemService {
    let item: ItemService
    let path: PathService
    let store: ActiveItemStore

    func focus(itemId: UUID) {
        func update(itemId: UUID) {
            let activeItemIds = store.activeItemIds.with { $0.insert(itemId) }
            withStoreUpdating {
                store.update(activeItemIds: activeItemIds)
                store.update(focusedItemId: itemId)
            }
        }

        let ancestors = item.idToAncestorIds[itemId]
        guard let ancestors, !ancestors.isEmpty else {
            update(itemId: itemId)
            return
        }

        let focusedIndex = ancestors.firstIndex { store.focusedItemId == $0 }
        if focusedIndex == 0 {
            update(itemId: itemId)
            return
        }
        if let focusedIndex {
            update(itemId: ancestors[focusedIndex - 1])
            return
        }

        let firstActive = ancestors.first { store.activeItemIds.contains($0) }
        if let firstActive {
            update(itemId: firstActive)
        } else {
            update(itemId: ancestors[ancestors.count - 1])
        }
    }

    func blur() {
        guard let focusedItemId = store.focusedItemId else {
            store.update(activeItemIds: .init())
            return
        }

        let activeItemIds = store.activeItemIds.with { $0.remove(focusedItemId) }
        let parentId = item.idToParentId[focusedItemId]
        withStoreUpdating {
            store.update(activeItemIds: activeItemIds)
            store.update(focusedItemId: parentId)
        }
    }
}
