import SwiftUI

// MARK: - Properties

extension DocumentPanel {
    struct Properties: View, SelectorHolder {
        class Selector: SelectorBase {
            @Selected({ global.document.activeDocument }) var activeDocument
            @Selected({ global.world.symbolIds }) var symbolIds
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

private extension DocumentPanel.Properties {
    @ViewBuilder var content: some View {
        PanelSection(name: "Properties") {
            ContextualRow(label: "ID") {
                Text(selector.activeDocument.id.description)
            }
            ContextualDivider()
            ContextualRow(label: "Name") {
                Text("Unnamed")
            }
            ContextualDivider()
            ContextualRow(label: "Symbols") {
                Text("\(selector.symbolIds.count)")
            }
        }
    }
}
