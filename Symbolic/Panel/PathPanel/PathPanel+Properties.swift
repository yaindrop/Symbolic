import SwiftUI

// MARK: - Properties

extension PathPanel {
    struct Properties: View, SelectorHolder {
        class Selector: SelectorBase {
            @Selected({ global.activeItem.focusedPath }) var path
            @Selected({ global.activeItem.focusedPathProperty }) var pathProperty
            @Selected({ global.focusedPath.focusedNodeId }) var focusedNodeId
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
        if let path = selector.path {
            PanelSection(name: "Properties") {
                ContextualRow(label: "ID") {
                    Text(path.id.description)
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
                    Button {} label: {
                        Text("Some Action")
                    }
                    .contextualFont()
                    Spacer()
                }
            }
        }
    }
}
