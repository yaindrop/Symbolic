import Foundation
import SwiftUI

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
    @Published var focusedPart: ActivePathFocusedPart?

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

    var activePath: Path? {
        pathStore.paths.first { $0.id == activePathId }
    }

    var pendingActivePath: Path? {
        pathStore.pendingPaths?.first { $0.id == activePathId } ?? activePath
    }

    func onActivePathChanged() {
        print("onActivePathChanged")
        if let part = focusedPart {
            if let path = activePath {
                if path.node(id: part.id) == nil {
                    focusedPart = nil
                }
            } else {
                focusedPart = nil
            }
        }
    }

    @ViewBuilder var inactivePathsView: some View {
        ForEach(pathStore.paths.filter { $0.id != activePathId }) { p in
            SUPath { path in p.draw(path: &path) }
                .stroke(Color(UIColor.label), lineWidth: 1)
        }
    }

    @ViewBuilder var activePathView: some View {
        if let pendingActivePath {
            SUPath { path in pendingActivePath.draw(path: &path) }
                .stroke(Color(UIColor.label), lineWidth: 1)
                .allowsHitTesting(false)
                .onChange(of: pendingActivePath) {
                    print("self.activePath", self.activePath)
                    print("self.pendingActivePath", self.pendingActivePath)
                }
        }
    }

    init(pathStore: PathStore) {
        self.pathStore = pathStore
    }

    private var pathStore: PathStore
}
