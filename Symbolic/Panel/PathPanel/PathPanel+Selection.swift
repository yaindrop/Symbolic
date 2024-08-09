import SwiftUI

// MARK: - Selection

extension PathPanel {
    struct Selection: View, SelectorHolder {
        class Selector: SelectorBase {
            @Selected({ global.activeItem.focusedPath }) var path
            @Selected({ global.focusedPath.selectingNodes }) var selectingNodes
            @Selected({ global.focusedPath.activeNodeIds }) var activeNodeIds
        }

        @SelectorWrapper var selector

        @State private var showPopover: Bool = false

        var body: some View {
            setupSelector {
                content
            }
        }
    }
}

// MARK: private

private extension PathPanel.Selection {
    @ViewBuilder var content: some View {
        PanelSection(name: "Selection") {
            if selector.selectingNodes {
                ContextualRow {
                    Text("\(selector.activeNodeIds.count) nodes selected")
                    Spacer()
                    Button { showPopover.toggle() } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .portal(isPresented: $showPopover) { PathSelectionPopover() }
                }
                ContextualDivider()
                ContextualRow {
                    Button("Invert") {
                        global.focusedPath.selectionInvert()
                    }
                    .contextualFont()
                    Spacer()
                    Button("Done") {
                        global.focusedPath.setSelecting(false)
                    }
                    .contextualFont()
                }
            } else {
                ContextualRow {
                    Button("Select Nodes", systemImage: "checklist") {
                        global.focusedPath.setSelecting(true)
                    }
                    .contextualFont()
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}
