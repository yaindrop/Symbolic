import Foundation
import SwiftUI

// MARK: - ActivePathFocusedPart

enum ActivePathFocusedPart: Equatable {
    case node(UUID)
    case edge(UUID)

    var id: UUID {
        switch self {
        case let .node(id): id
        case let .edge(id): id
        }
    }
}

// MARK: - ActivePathModel

class ActivePathModel: Store {
    @Trackable var activePathId: UUID?
    @Trackable var focusedPart: ActivePathFocusedPart?

    func update(activePathId: UUID?) {
        update { $0(\._activePathId, activePathId) }
    }

    fileprivate func update(focusedPart: ActivePathFocusedPart?) {
        update { $0(\._focusedPart, focusedPart) }
    }
}

// MARK: - ActivePathService

struct ActivePathService {
    let pathModel: PathModel
    let pendingPathModel: PendingPathModel
    let model: ActivePathModel

    var activePathId: UUID? { model.activePathId }

    var activePath: Path? {
        service.path.model.paths.first { $0.id == activePathId }
    }

    var pendingActivePath: Path? {
        service.path.pendingModel.hasPendingEvent ? service.path.pendingModel.paths.first { $0.id == activePathId } : activePath
    }

    var focusedPart: ActivePathFocusedPart? { model.focusedPart }

    var focusedEdgeId: UUID? {
        guard let focusedPart,
              case let .edge(id) = focusedPart else { return nil }
        return id
    }

    var focusedNodeId: UUID? {
        guard let focusedPart,
              case let .node(id) = focusedPart else { return nil }
        return id
    }

    func setFocus(node id: UUID) {
        let _r = tracer.range("[active-path] set focus", type: .intent); defer { _r() }
        withAnimation { model.update(focusedPart: .node(id)) }
    }

    func setFocus(edge fromNodeId: UUID) {
        let _r = tracer.range("[active-path] set focus", type: .intent); defer { _r() }
        withAnimation { model.update(focusedPart: .edge(fromNodeId)) }
    }

    func clearFocus() {
        let _r = tracer.range("[active-path] clear focus", type: .intent); defer { _r() }
        withAnimation { model.update(focusedPart: nil) }
    }

    func onActivePathChanged() {
        if let part = model.focusedPart {
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
