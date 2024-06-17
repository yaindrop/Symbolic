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
    var offset: CGSize {
        guard let panel = selector.panel else { return .zero }
        switch selector.floatingState {
        case .primary: return .zero
        case .secondary, .hidden:
            switch panel.align {
            case .topLeading: return .init(24, -24)
            case .topTrailing: return .init(-24, -24)
            case .bottomLeading: return .init(24, 24)
            case .bottomTrailing: return .init(-24, 24)
            default: return .zero
            }
        }
    }

    var rotation: Angle {
        guard let panel = selector.panel else { return .zero }
        switch selector.floatingState {
        case .primary: return .zero
        case .secondary: return .degrees(panel.align.isLeading ? -30 : 30)
        case .hidden: return .degrees(panel.align.isLeading ? -45 : 45)
        }
    }

    var scale: Scalar {
        switch selector.floatingState {
        case .primary: return 1
        case .secondary: return 0.4
        case .hidden: return 0.2
        }
    }

    var anchor: UnitPoint {
        guard let panel = selector.panel else { return .zero }
        switch panel.align {
        case .topLeading: return .topTrailing
        case .topTrailing: return .topLeading
        case .bottomLeading: return .bottomTrailing
        case .bottomTrailing: return .bottomLeading
        default: return .topLeading
        }
    }

    var opacity: Scalar {
        switch selector.floatingState {
        case .primary: return 1
        case .secondary: return 0.6
        case .hidden: return 0
        }
    }

    @ViewBuilder var content: some View {
        if let panel = selector.panel {
            panel.view(panel.id)
                .id(panel.id)
                .sizeReader { global.panel.onResized(panelId: panel.id, size: $0) }
                .offset(.init(selector.offset))
                .if(selector.floatingState == .secondary) {
                    $0.invisibleSoildOverlay()
                        .multipleGesture(global.panel.moveGesture(panelId: panelId))
                }
                .scaleEffect(scale, anchor: anchor)
                .rotation3DEffect(rotation, axis: (x: 0, y: 1, z: 0), anchor: anchor)
                .padding(.horizontal, 12)
                .padding(.vertical, 24)
                .offset(offset)
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
