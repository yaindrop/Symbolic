import SwiftUI

// MARK: - ItemPanel

struct ItemPanel: View, TracedView, SelectorHolder {
    let panelId: UUID

    class Selector: SelectorBase {
        @Selected({ global.item.rootIds }) var rootIds
    }

    @SelectorWrapper var selector

    @StateObject private var scrollViewModel = ManagedScrollViewModel()

    var body: some View { trace {
        setupSelector {
            content.frame(width: 320)
        }
    } }
}

// MARK: private

extension ItemPanel {
    @ViewBuilder private var content: some View {
        PanelBody(panelId: panelId, name: "Items", maxHeight: 400) { _ in
            items
        }
    }

    @ViewBuilder private var items: some View {
        PanelSection(name: "Items") {
            ForEach(selector.rootIds) {
                ItemRow(itemId: $0)
                if $0 != selector.rootIds.last {
                    Divider().padding(.leading, 12)
                }
            }
        }
    }
}
