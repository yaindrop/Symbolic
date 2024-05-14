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

@Observable
class ActivePathModel {
    var activePathId: UUID?
    fileprivate(set) var focusedPart: ActivePathFocusedPart?
}

// MARK: - EnableActivePathInteractor

protocol EnableActivePathInteractor {
    var pathModel: PathModel { get }
    var pendingPathModel: PendingPathModel { get }
    var activePathModel: ActivePathModel { get }
}

extension EnableActivePathInteractor {
    var activePathInteractor: ActivePathInteractor { .init(pathModel: pathModel, pendingPathModel: pendingPathModel, model: activePathModel) }
}

// MARK: - ActivePathInteractor

struct ActivePathInteractor: EnablePathInteractor {
    let pathModel: PathModel
    let pendingPathModel: PendingPathModel
    let model: ActivePathModel

    var activePathId: UUID? { model.activePathId }
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

    func setFocus(node id: UUID) { withAnimation { model.focusedPart = .node(id) } }

    func setFocus(edge fromNodeId: UUID) { withAnimation { model.focusedPart = .edge(fromNodeId) } }

    func clearFocus() { withAnimation { model.focusedPart = nil } }

    var activePath: Path? {
        pathInteractor.model.paths.first { $0.id == activePathId }
    }

    var pendingActivePath: Path? {
        pathInteractor.pendingModel.hasPendingEvent ? pathInteractor.pendingModel.paths.first { $0.id == activePathId } : activePath
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

    @ViewBuilder var inactivePathsView: some View {
        ForEach(pathInteractor.model.paths.filter { $0.id != activePathId }) { p in
            SUPath { path in p.append(to: &path) }
                .stroke(Color(UIColor.label), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
        }
    }

    @ViewBuilder var activePathView: some View {
        if let pendingActivePath {
            SUPath { path in pendingActivePath.append(to: &path) }
                .stroke(Color(UIColor.label), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
                .allowsHitTesting(false)
                .id(pendingActivePath.id)
        }
    }
}
