import SwiftUI

// MARK: - Properties

extension PathPanel {
    struct Properties: View, SelectorHolder {
        class Selector: SelectorBase {
            @Selected({ global.activeItem.focusedPathId }) var pathId
            @Selected({ global.activeItem.focusedPath }) var path
            @Selected({ global.activeItem.focusedPathProperty }) var pathProperty
            @Selected({ global.focusedPath.focusedNodeId }) var focusedNodeId
            @Selected({ global.focusedPath.selectingNodes }) var selectingNodes
        }

        @SelectorWrapper var selector

        var body: some View {
            setupSelector {
                content
            }
        }
    }
}

// MARK: private

private extension PathPanel.Properties {
    @ViewBuilder var content: some View {
        if let pathId = selector.pathId, let path = selector.path {
            PanelSection(name: "Properties") {
                ContextualRow(label: "ID") {
                    Text(pathId.description)
                }
                ContextualDivider()
                ContextualRow(label: "Name") {
                    Text("Unnamed")
                }
                ContextualDivider()
                ContextualRow(label: "Nodes") {
                    Text("\(path.nodes.count)")
                }
                ContextualDivider()
                ContextualRow {
                    Button("Zoom In", systemImage: "arrow.up.left.and.arrow.down.right") {
                        global.viewportUpdater.zoomTo(rect: path.boundingRect)
                    }
                    .contextualFont()
                    Spacer()
                }
            }
        }
    }
}
