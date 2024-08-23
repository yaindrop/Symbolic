import SwiftUI

// MARK: - Selection

extension ItemPanel {
    struct Selection: View, SelectorHolder {
        class Selector: SelectorBase {
            @Selected(configs: .init(animation: .fast), { global.activeItem.activeItemIds }) var activeItemIds
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

private extension ItemPanel.Selection {
    @ViewBuilder var content: some View {
        PanelSection(name: "Selection") {
            if !selector.activeItemIds.isEmpty {
                ContextualRow {
                    Text("\(selector.activeItemIds.count) items selected")
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
