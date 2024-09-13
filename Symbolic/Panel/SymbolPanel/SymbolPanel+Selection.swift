import SwiftUI

// MARK: - Selection

extension SymbolPanel {
    struct Selection: View, SelectorHolder {
        class Selector: SelectorBase {
            @Selected({ global.activeItem.selectedItemIds }, .animation(.fast)) var selectedItemIds
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

private extension SymbolPanel.Selection {
    @ViewBuilder var content: some View {
        PanelSection(name: "Selection") {
            if !selector.selectedItemIds.isEmpty {
                ContextualRow {
                    Text("\(selector.selectedItemIds.count) items selected")
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
                    Text("No Selection")
                        .contextualFont()
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}
