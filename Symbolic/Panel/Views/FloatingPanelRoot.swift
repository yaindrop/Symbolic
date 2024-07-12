import SwiftUI

private let debug: Bool = false

// MARK: - FloatingPanelWrapper

struct FloatingPanelWrapper: View, TracedView, EquatableBy, ComputedSelectorHolder {
    let panelId: UUID

    var equatableBy: some Equatable { panelId }

    struct SelectorProps: Equatable { let panelId: UUID }
    class Selector: SelectorBase {
        @Selected({ global.panel.get(id: $0.panelId) }) var panel
        @Selected({ global.panel.floatingPanelWidth }) var width
        @Selected({ global.panel.floatingAlign(id: $0.panelId) }) var align
        @Selected({ global.panel.moving(id: $0.panelId)?.offset ?? .zero }) var offset
        @Selected({ global.panel.moving(id: $0.panelId)?.ended ?? false }) var ended
        @Selected(configs: .init(animation: .fast), { global.panel.floatingPadding(id: $0.panelId) }) var padding
        @Selected(configs: .init(animation: .fast), { global.panel.appearance(id: $0.panelId) }) var appearance
    }

    @SelectorWrapper var selector

    var body: some View { trace {
        setupSelector(.init(panelId: panelId)) {
            content
                .onChange(of: selector.ended) {
                    if selector.ended {
                        global.panel.resetMoving(panelId: panelId)
                    }
                }
        }
    } }
}

// MARK: private

private extension FloatingPanelWrapper {
    var secondaryOffset: Vector2 {
        let size: Vector2 = .init(20, 20)
        switch selector.appearance {
        case .floatingSecondary, .floatingHidden:
            switch selector.align {
            case .topLeading: return -size
            case .topTrailing: return -size.flipX
            case .bottomLeading: return size.flipX
            case .bottomTrailing: return size
            default: return .zero
            }
        default: return .zero
        }
    }

    var rotation: Angle {
        let secondaryAngle: Scalar = 30
        let hiddenAngle: Scalar = 45
        switch selector.appearance {
        case .floatingSecondary: return .degrees((selector.align.isLeading ? 1 : -1) * secondaryAngle)
        case .floatingHidden: return .degrees((selector.align.isLeading ? 1 : -1) * hiddenAngle)
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

    var opacity: Scalar {
        switch selector.appearance {
        case .floatingSecondary: 0.6
        case .floatingHidden: 0
        default: 1
        }
    }

    @ViewBuilder var content: some View {
        if let panel = selector.panel {
            PanelView(panel: panel)
                .frame(width: selector.width)
                .offset(.init(selector.offset))
                .scaleEffect(scale, anchor: selector.align.unitPoint)
                .rotation3DEffect(rotation, axis: (x: 0, y: 1, z: 0), anchor: selector.align.unitPoint)
                .geometryReader { global.panel.setFrame(panelId: panelId, $0.frame(in: .global)) }
                .padding(size: selector.padding)
                .offset(.init(secondaryOffset))
                .background(debug ? .blue.opacity(0.1) : .clear)
                .innerAligned(selector.align)
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
            ForEach(selector.floatingPanelIds) { FloatingPanelWrapper(panelId: $0) }
        }
        .geometryReader { global.panel.setRootFrame($0.frame(in: .global)) }
        .background(debug ? .yellow.opacity(0.2) : .clear)
    }
}
