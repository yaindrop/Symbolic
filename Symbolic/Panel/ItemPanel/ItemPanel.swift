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
        VStack(spacing: 0) {
            PanelTitle(name: "Items")
                .if(scrollViewModel.scrolled) { $0.background(.regularMaterial) }
                .invisibleSoildOverlay()
                .multipleGesture(global.panel.moveGesture(panelId: panelId))
            scrollView
        }
        .background(.ultraThinMaterial)
        .clipRounded(radius: 12)
    }

    @ViewBuilder private var scrollView: some View {
        ManagedScrollView(model: scrollViewModel) { _ in
            items
        }
        .frame(maxHeight: 400)
        .fixedSize(horizontal: false, vertical: true)
        .scrollBounceBehavior(.basedOnSize, axes: [.vertical])
    }

    @ViewBuilder private var items: some View {
        VStack(spacing: 4) {
            PanelSectionTitle(name: "Items")
            VStack(spacing: 0) {
                ForEach(selector.rootIds) {
                    ItemRow(itemId: $0)
                    if $0 != selector.rootIds.last {
                        Divider().padding(.leading, 12)
                    }
                }
            }
            .background(.ultraThickMaterial)
            .clipRounded(radius: 12)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 24)
    }
}
