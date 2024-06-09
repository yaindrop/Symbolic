import SwiftUI

// MARK: - PathPanel

struct PathPanel: View, TracedView, SelectorHolder {
    let panelId: UUID

    class Selector: SelectorBase {
        @Selected({ global.activeItem.focusedPath }) var path
        @Selected({ global.focusedPath.focusedNodeId }) var focusedNodeId
        @Selected({ global.focusedPath.focusedSegmentId }) var focusedSegmentId
    }

    @SelectorWrapper var selector

    @StateObject private var scrollViewModel = ManagedScrollViewModel()

    var body: some View { trace {
        setupSelector {
            panel.frame(width: 320)
        }
    } }
}

// MARK: private

private extension PathPanel {
    @ViewBuilder var panel: some View {
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

    @ViewBuilder var scrollView: some View {
        ManagedScrollView(model: scrollViewModel) { proxy in
            nodes
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

    @ViewBuilder var nodes: some View {
        if let path = selector.path {
            VStack(spacing: 4) {
                PanelSectionTitle(name: "Nodes")
                VStack(spacing: 0) {
                    ForEach(path.nodes) { node in
                        NodeRow(pathId: path.id, nodeId: node.id)
                        if node.id != path.nodes.last?.id {
                            Divider().padding(.leading, 12)
                        }
                    }
                }
                .background(.ultraThickMaterial)
                .clipRounded(radius: 12)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 24)
            .id(path.id)
        }
    }
}
