import SwiftUI

// MARK: - PanelView

struct FloatingPanelView: View, TracedView, EquatableBy, ComputedSelectorHolder {
    let panelId: UUID

    var equatableBy: some Equatable { panelId }

    struct SelectorProps: Equatable { let panelId: UUID }
    class Selector: SelectorBase {
        override var syncUpdate: Bool { true }
        @Selected({ global.panel.get(id: $0.panelId) }) var panel
        @Selected({ global.panel.moving(id: $0.panelId)?.offset ?? .zero }) var offset
        @Selected(animation: .default, { global.panel.floatingState(id: $0.panelId) }) var floatingState
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
                .offset(.init(selector.offset))
                .scaleEffect(selector.floatingState == .secondary ? 0.3 : 1, anchor: .leading)
                .rotation3DEffect(selector.floatingState == .secondary ? .degrees(60) : .zero, axis: (x: 0, y: 1, z: 0))
                .padding(12)
                .padding(.horizontal, selector.floatingState == .secondary ? 60 : 0)
                .innerAligned(panel.align)
                .opacity(selector.floatingState == .hidden ? 0 : 1)
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
            .geometryReader { global.panel.setRootRect($0.frame(in: .global)) }
        }
    } }
}
