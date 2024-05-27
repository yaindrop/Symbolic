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

    fileprivate func update(activeItemIds: Set<UUID>) {
        update { $0(\._activeItemIds, activeItemIds) }
    }

    fileprivate func update(focusedItemId: UUID?) {
        update { $0(\._focusedItemId, focusedItemId) }
    }

    fileprivate func update(pathFocusedPart: PathFocusedPart?) {
        update { $0(\._pathFocusedPart, pathFocusedPart) }
    }
}

// MARK: - ActiveItemService

struct ActiveItemService {
    let item: ItemService
    let path: PathService
    let store: ActiveItemStore

    var focusedItemId: UUID? { store.focusedItemId }

    var activePath: Path? {
        if let focusedItemId {
            return path.map[focusedItemId]
        }
        return nil
    }

    func focus(itemId: UUID) {
        let ancestors = item.idToAncestorIds[itemId]
        if let ancestors, !ancestors.isEmpty {
            let lastInactive = ancestors.last { !store.activeItemIds.contains($0) }
            let toFocus = lastInactive ?? itemId
            let activeItemIds = store.activeItemIds.with { $0.insert(toFocus) }
            withStoreUpdating {
                store.update(activeItemIds: activeItemIds)
                store.update(focusedItemId: toFocus)
            }
        } else {
            withStoreUpdating {
                store.update(activeItemIds: [itemId])
                store.update(focusedItemId: itemId)
            }
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

    var pathFocusedPart: PathFocusedPart? { store.pathFocusedPart }

    func setFocus(node id: UUID) {
        let _r = subtracer.range("set focus", type: .intent); defer { _r() }
        withAnimation { store.update(pathFocusedPart: .node(id)) }
    }

    func setFocus(edge fromNodeId: UUID) {
        let _r = subtracer.range("set focus", type: .intent); defer { _r() }
        withAnimation { store.update(pathFocusedPart: .edge(fromNodeId)) }
    }

    func clearFocus() {
        let _r = subtracer.range("clear focus", type: .intent); defer { _r() }
        withAnimation { store.update(pathFocusedPart: nil) }
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
