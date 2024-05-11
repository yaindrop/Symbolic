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

class ActivePathModel: ObservableObject {
    @Published var activePathId: UUID?
    @Published fileprivate(set) var focusedPart: ActivePathFocusedPart?
}

// MARK: - ActivePathInteractor

struct ActivePathInteractor {
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
        pathModel.paths.first { $0.id == activePathId }
    }

    var pendingActivePath: Path? {
        pathModel.pendingPaths?.first { $0.id == activePathId } ?? activePath
    }

    func onActivePathChanged() {
        print("onActivePathChanged", activePath?.id)
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
        ForEach(pathModel.paths.filter { $0.id != activePathId }) { p in
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

    init(_ pathModel: PathModel, _ model: ActivePathModel) {
        self.pathModel = pathModel
        self.model = model
    }

    private let pathModel: PathModel
    private let model: ActivePathModel
}
