import Foundation
import SwiftUI

// MARK: - ActivePathHandles

struct ActivePathHandles: View {
    var body: some View {
        if let activePath = activePathModel.pendingActivePath {
            ZStack {
                let segments = activePath.segments
                ForEach(segments) { s in ActivePathEdgeHandle(segment: s, data: s.data.applying(viewport.toView)) }
                ForEach(segments) { s in ActivePathNodeHandle(segment: s, data: s.data.applying(viewport.toView)) }
                ForEach(segments) { s in ActivePathFocusedEdgeHandle(segment: s, data: s.data.applying(viewport.toView)) }
                ForEach(segments) { s in ActivePathEdgeKindHandle(segment: s, data: s.data.applying(viewport.toView)) }
            }
        }
    }

    @EnvironmentObject private var viewport: Viewport
    @EnvironmentObject private var documentModel: DocumentModel
    @EnvironmentObject private var pathStore: PathStore
    @EnvironmentObject private var activePathModel: ActivePathModel
}
