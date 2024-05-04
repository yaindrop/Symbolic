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
    @Published private(set) var focusedPart: ActivePathFocusedPart?

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

    func setFocus(node id: UUID) { withAnimation { focusedPart = .node(id) } }

    func setFocus(edge fromNodeId: UUID) { withAnimation { focusedPart = .edge(fromNodeId) } }

    func clearFocus() { withAnimation { focusedPart = nil } }

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
            SUPath { path in p.append(to: &path) }
                .stroke(Color(UIColor.label), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
        }
    }

    @ViewBuilder var activePathView: some View {
        if let pendingActivePath {
            SUPath { path in pendingActivePath.append(to: &path) }
                .stroke(Color(UIColor.label), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
                .allowsHitTesting(false)
        }
    }

    init(pathStore: PathStore) {
        self.pathStore = pathStore
    }

    private var pathStore: PathStore
}
