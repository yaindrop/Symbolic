import SwiftUI

// MARK: - PathPanel

struct PathPanel: View, TracedView, SelectorHolder {
    @Environment(\.panelScrollProxy) private var panelScrollProxy

    class Selector: SelectorBase {
        @Selected({ global.activeItem.focusedPath }) var path
        @Selected({ global.focusedPath.focusedNodeId }) var focusedNodeId
        @Selected({ global.focusedPath.focusedSegmentId }) var focusedSegmentId
    }

    @SelectorWrapper var selector

    var body: some View { trace {
        setupSelector {
            content
        }
    } }
}

// MARK: private

private extension PathPanel {
    @ViewBuilder var content: some View {
        nodes
            .onChange(of: selector.focusedNodeId) {
                guard let id = selector.focusedNodeId else { return }
                withAnimation(.easeInOut(duration: 0.2)) { panelScrollProxy?.scrollTo(id, anchor: .center) }
            }
            .onChange(of: selector.focusedSegmentId) {
                guard let id = selector.focusedSegmentId else { return }
                withAnimation(.easeInOut(duration: 0.2)) { panelScrollProxy?.scrollTo(id, anchor: .center) }
            }
        if selector.path == nil {
            placeholder
        }
    }

    @ViewBuilder var nodes: some View {
        if let path = selector.path {
            PanelSection(name: "Nodes") {
                ForEach(path.nodeIds) { nodeId in
                    NodeRow(pathId: path.id, nodeId: nodeId)
                    if nodeId != path.nodeIds.last {
                        Divider().padding(.leading, 12)
                    }
                }
            }
        }
    }

    @ViewBuilder var placeholder: some View {
        Text("No path is focused")
            .font(.callout)
            .foregroundStyle(Color.label.opacity(0.5))
            .frame(maxWidth: .infinity, idealHeight: 72)
            .background(.ultraThinMaterial)
            .clipRounded(radius: 12)
    }
}
