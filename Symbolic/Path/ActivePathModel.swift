import Foundation
import SwiftUI

fileprivate let activePathTracer = tracer.tagged("active-path")

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

// MARK: - ActivePathModel

class ActivePathStore: Store {
    @Trackable var activePathId: UUID?
    @Trackable var focusedPart: PathFocusedPart?

    func update(activePathId: UUID?) {
        update { $0(\._activePathId, activePathId) }
    }

    fileprivate func update(focusedPart: PathFocusedPart?) {
        update { $0(\._focusedPart, focusedPart) }
    }
}

// MARK: - ActivePathService

struct ActivePathService {
    let pathStore: PathStore
    let pendingPathStore: PendingPathStore
    let store: ActivePathStore

    var activePathId: UUID? { store.activePathId }

    var activePath: Path? {
        pathStore.paths.first { $0.id == activePathId }
    }

    var pendingActivePath: Path? {
        pendingPathStore.hasPendingEvent ? pendingPathStore.paths.first { $0.id == activePathId } : activePath
    }

    var focusedPart: PathFocusedPart? { store.focusedPart }

    func setFocus(node id: UUID) {
        let _r = activePathTracer.range("set focus", type: .intent); defer { _r() }
        withAnimation { store.update(focusedPart: .node(id)) }
    }

    func setFocus(edge fromNodeId: UUID) {
        let _r = activePathTracer.range("set focus", type: .intent); defer { _r() }
        withAnimation { store.update(focusedPart: .edge(fromNodeId)) }
    }

    func clearFocus() {
        let _r = activePathTracer.range("clear focus", type: .intent); defer { _r() }
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
