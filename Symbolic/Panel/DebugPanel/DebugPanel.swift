import SwiftUI

// MARK: - DebugPanel

struct DebugPanel: View, SelectorHolder {
    class Selector: SelectorBase {
        @Selected({ global.viewport.info }) var viewportInfo
    }

    @SelectorWrapper var selector

    var body: some View {
        setupSelector {
            content
        }
    }
}

// MARK: private

private extension DebugPanel {
    @ViewBuilder var content: some View {
        viewport
    }

    @ViewBuilder var viewport: some View {
        PanelSection(name: "Viewport") {
            ContextualRow(label: "Origin") {
                Text(selector.viewportInfo.origin.shortDescription)
                    .contextualFont()
            }
            ContextualDivider()
            ContextualRow(label: "Scale") {
                Text(selector.viewportInfo.scale.shortDescription)
                    .contextualFont()
            }
        }
    }
}
