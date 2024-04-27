import Foundation
import SwiftUI

enum ActivePathFocusedPart: Equatable {
    case vertex(UUID)
    case segment(UUID)

    var id: UUID {
        switch self {
        case let .vertex(id): id
        case let .segment(id): id
        }
    }
}

// MARK: - ActivePathModel

class ActivePathModel: ObservableObject {
    @Published var activePathId: UUID?
    @Published var focusedPart: ActivePathFocusedPart?

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
        }
    }

    init(pathStore: PathStore) {
        self.pathStore = pathStore
    }

    private var pathStore: PathStore
}
