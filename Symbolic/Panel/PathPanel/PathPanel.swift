import Foundation
import SwiftUI

// MARK: - PathPanel

struct PathPanel: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        @Selected({ global.activeItem.focusedPath }) var path
        @Selected({ global.focusedPath.focusedNodeId }) var focusedNodeId
        @Selected({ global.focusedPath.focusedSegmentId }) var focusedSegmentId
    }

    @SelectorWrapper var selector

    let panelId: UUID

    var body: some View { trace {
        setupSelector {
            panel.frame(width: 320)
        }
    } }

    // MARK: private

    @StateObject private var scrollViewModel = ManagedScrollViewModel()

    @ViewBuilder private var panel: some View {
        VStack(spacing: 0) {
            PanelTitle(name: "Path")
                .if(scrollViewModel.scrolled) { $0.background(.regularMaterial) }
                .invisibleSoildOverlay()
                .multipleGesture(global.panel.moveGesture(panelId: panelId))
            scrollView
        }
        .background(.ultraThinMaterial)
        .clipRounded(radius: 12)
    }

    @ViewBuilder private var scrollView: some View {
        if let path = selector.path {
            ManagedScrollView(model: scrollViewModel) { proxy in
                Nodes(path: path).id(path.id)
                    .onChange(of: selector.focusedNodeId) {
                        guard let id = selector.focusedNodeId else { return }
                        withAnimation(.easeInOut(duration: 0.2)) { proxy.scrollTo(id, anchor: .center) }
                    }
                    .onChange(of: selector.focusedSegmentId) {
                        guard let id = selector.focusedSegmentId else { return }
                        withAnimation(.easeInOut(duration: 0.2)) { proxy.scrollTo(id, anchor: .center) }
                    }
            }
            .frame(maxHeight: 400)
            .fixedSize(horizontal: false, vertical: true)
            .scrollBounceBehavior(.basedOnSize, axes: [.vertical])
        }
    }
}
