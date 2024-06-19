import SwiftUI

// MARK: - FloatingPanelView

struct FloatingPanelView: View, TracedView, EquatableBy, ComputedSelectorHolder {
    let panelId: UUID

    var equatableBy: some Equatable { panelId }

    struct SelectorProps: Equatable { let panelId: UUID }
    class Selector: SelectorBase {
//        override var syncNotify: Bool { true }
        @Selected({ global.panel.get(id: $0.panelId) }) var panel
        @Selected({ global.panel.moving(id: $0.panelId)?.offset ?? .zero }) var offset
        @Selected(animation: .default, { global.panel.appearance(id: $0.panelId) }) var appearance
    }

    @SelectorWrapper var selector

    var body: some View { trace {
        setupSelector(.init(panelId: panelId)) {
            content
        }
    } }
}

// MARK: private

private extension FloatingPanelView {
    var width: Scalar { 320 }

    var gap: Vector2 { .init(10, 20) }

    var secondaryOffset: Vector2 { .init(24, 18) }

    var offset: Vector2 {
        guard let panel = selector.panel else { return .zero }
        switch selector.appearance {
        case .floatingSecondary, .floatingHidden:
            switch panel.align {
            case .topLeading: return secondaryOffset.flipY
            case .topTrailing: return -secondaryOffset
            case .bottomLeading: return secondaryOffset
            case .bottomTrailing: return secondaryOffset.flipX
            default: return .zero
            }
        default: return .zero
        }
    }

    var secondaryAngle: Scalar { 30 }

    var hiddenAngle: Scalar { 45 }

    var rotation: Angle {
        guard let panel = selector.panel else { return .zero }
        switch selector.appearance {
        case .floatingSecondary: return .degrees((panel.align.isLeading ? -1 : 1) * secondaryAngle)
        case .floatingHidden: return .degrees((panel.align.isLeading ? -1 : 1) * hiddenAngle)
        default: return .zero
        }
    }

    var scale: Scalar {
        switch selector.appearance {
        case .floatingSecondary: 0.4
        case .floatingHidden: 0.2
        default: 1
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
        switch selector.appearance {
        case .floatingSecondary: 0.6
        case .floatingHidden: 0
        default: 1
        }
    }

    @ViewBuilder var content: some View {
        if let panel = selector.panel {
            panel.view
                .frame(width: width)
                .environment(\.panelId, panelId)
                .id(panel.id)
                .sizeReader { global.panel.onResized(panelId: panel.id, size: $0) }
                .offset(.init(selector.offset))
                .scaleEffect(scale, anchor: anchor)
                .rotation3DEffect(rotation, axis: (x: 0, y: 1, z: 0), anchor: anchor)
                .padding(.horizontal, gap.dx)
                .padding(.vertical, gap.dy)
                .offset(.init(offset))
                .innerAligned(panel.align)
                .opacity(selector.appearance == .floatingHidden ? 0 : 1)
        }
    }
}

// MARK: - FloatingPanelRoot

struct FloatingPanelRoot: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        @Selected({ global.panel.floatingPanelIds }) var floatingPanelIds
    }

    @SelectorWrapper var selector

    var body: some View { trace {
        setupSelector {
            content
        }
    } }
}

// MARK: private

private extension FloatingPanelRoot {
    var content: some View {
        ZStack {
            ForEach(selector.floatingPanelIds) { FloatingPanelView(panelId: $0) }
        }
        .geometryReader { global.panel.setRootRect($0.frame(in: .global)) }
    }
}
