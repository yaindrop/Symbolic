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
        PanelBody(panelId: panelId, name: "Path", maxHeight: 400) { proxy in
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
    }

    @ViewBuilder var nodes: some View {
        if let path = selector.path {
            PanelSection(name: "Nodes") {
                ForEach(path.nodes) { node in
                    NodeRow(pathId: path.id, nodeId: node.id)
                    if node.id != path.nodes.last?.id {
                        Divider().padding(.leading, 12)
                    }
                }
            }
        }
    }
}
