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
