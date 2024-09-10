import SwiftUI

// MARK: - PathPanel

struct PathPanel: View, TracedView, SelectorHolder {
    @Environment(\.panelScrollProxy) private var panelScrollProxy

    class Selector: SelectorBase {
        @Selected({ global.activeItem.focusedPathId }) var focusedPathId
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
        if selector.focusedPathId != nil {
            Properties()
            Selection()
            Nodes()
                .onChange(of: selector.focusedNodeId) {
                    guard let id = selector.focusedNodeId else { return }
                    withAnimation(.easeInOut(duration: 0.2)) { panelScrollProxy?.scrollTo(id, anchor: .center) }
                }
                .onChange(of: selector.focusedSegmentId) {
                    guard let id = selector.focusedSegmentId else { return }
                    withAnimation(.easeInOut(duration: 0.2)) { panelScrollProxy?.scrollTo(id, anchor: .center) }
                }
        } else {
            PanelPlaceholder(text: "No path is focused")
        }
    }
}
