import Foundation
import SwiftUI

// MARK: - ActivePathModel

class ActivePathModel: ObservableObject {
    @Published var activePathId: UUID?

    var activePath: Path? {
        pathStore.paths.first { $0.id == activePathId }
    }

    var pendingActivePath: Path? {
        pathStore.pendingPaths?.first { $0.id == activePathId } ?? activePath
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
