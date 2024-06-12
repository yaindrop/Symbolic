import SwiftUI

// MARK: - PanelView

struct FloatingPanelView: View, TracedView, EquatableBy, ComputedSelectorHolder {
    let panelId: UUID

    var equatableBy: some Equatable { panelId }

    struct SelectorProps: Equatable { let panelId: UUID }
    class Selector: SelectorBase {
        @Selected(syncUpdate: true, { global.panel.panel(id: $0.panelId) }) var panel
    }

    @SelectorWrapper var selector

    var body: some View { trace {
        setupSelector(.init(panelId: panelId)) {
            content
        }
    } }
}

private extension FloatingPanelView {
    @ViewBuilder var content: some View {
        if let panel = selector.panel {
            panel.view(panel.id)
                .id(panel.id)
                .sizeReader { global.panel.onResized(panelId: panel.id, size: $0) }
                .offset(x: panel.origin.x, y: panel.origin.y)
                .innerAligned(.topLeading)
        }
    }
}

// MARK: - PanelRoot

struct PanelRoot: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        @Selected({ global.panel.floatingPanelIds }) var floatingPanelIds
    }

    @SelectorWrapper var selector

    var body: some View { trace {
        setupSelector {
            ZStack {
                ForEach(selector.floatingPanelIds) { FloatingPanelView(panelId: $0) }
            }
            .sizeReader { global.panel.onRootResized(size: $0) }
        }
    } }
}
