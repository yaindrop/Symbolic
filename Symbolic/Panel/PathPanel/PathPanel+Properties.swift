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
                PanelSectionRow(label: "ID") {
                    Text(path.id.description)
                }
                PanelSectionDivider()
                PanelSectionRow(label: "Name") {
                    Text("Unnamed")
                }
                PanelSectionDivider()
                PanelSectionRow(label: "Nodes") {
                    Text("\(path.nodes.count)")
                }
                PanelSectionDivider()
                PanelSectionRow {
                    Button {} label: {
                        Text("Some Action")
                    }
                    .font(.callout)
                    Spacer()
                }
            }
        }
    }
}
