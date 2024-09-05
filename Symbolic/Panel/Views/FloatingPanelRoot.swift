import SwiftUI

// MARK: - FloatingPanelView

struct FloatingPanelView: View, TracedView, ComputedSelectorHolder {
    @Environment(\.panelId) var panelId
    @Environment(\.panelAppearance) var appearance

    struct SelectorProps: Equatable { let panelId: UUID }
    class Selector: SelectorBase {
        @Selected({ global.panel.get(id: $0.panelId)?.name ?? "" }) var panelName
        @Selected({ global.panel.floatingWidth }) var width
        @Selected({ global.panel.style(id: $0.panelId)?.maxHeight ?? 0 }) var maxHeight
        @Selected({ global.panel.movable(of: $0.panelId) }) var movable
    }

    @SelectorWrapper var selector

    @State private var titleSize: CGSize = .zero

    @StateObject private var scrollViewModel = ManagedScrollViewModel()

    @State private var scrollFrame: CGRect = .zero

    var body: some View { trace {
        setupSelector(.init(panelId: panelId)) {
            trace(selector.panelName) {
                content
                    .id(panelId)
            }
        }
    } }
}

// MARK: private

private extension FloatingPanelView {
    var content: some View {
        VStack(spacing: 0) {
            title
                .zIndex(2)
            scrollView
                .zIndex(1)
        }
        .frame(width: selector.width)
        .background { background }
        .overlay { secondaryOverlay }
        .clipRounded(radius: 18)
        .overlay { HeightControl() }
        .overlay { Switcher() }
    }

    var titleBackgroundOpacity: Scalar { min(scrollViewModel.offset, 12) / 12.0 }

    @ViewBuilder var title: some View {
        Text(selector.panelName)
            .font(.headline)
            .padding(.vertical, 8)
            .aligned(axis: .horizontal, .center)
            .padding(.horizontal, 12)
            .invisibleSoildOverlay()
            .multipleGesture(selector.movable ? global.panel.movingGesture(of: panelId) : nil)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial.opacity(titleBackgroundOpacity))
            .sizeReader { titleSize = $0 }
        Divider()
            .opacity(titleBackgroundOpacity)
    }

    @ViewBuilder var scrollView: some View {
        ManagedScrollView(model: scrollViewModel) { proxy in
            VStack(spacing: 12) {
                Memo {
                    global.panel.get(id: panelId)?.view
                }
            }
            .padding(.all.subtracting(.top), 12)
            .environment(\.panelScrollProxy, proxy)
            .environment(\.panelScrollFrame, scrollFrame)
        }
        .scrollClipDisabled()
        .scrollBounceBehavior(.basedOnSize, axes: [.vertical])
        .frame(maxWidth: .infinity, maxHeight: max(0, selector.maxHeight - titleSize.height))
        .fixedSize(horizontal: false, vertical: true)
        .geometryReader { scrollFrame = $0.frame(in: .global) }
    }

    var background: some View {
        Rectangle()
            .if(appearance == .floatingPrimary) {
                $0.fill(.ultraThinMaterial)
            } else: {
                $0.fill(.background.secondary.opacity(0.8))
            }
    }

    var titleBackground: some View {
        Rectangle()
            .if(appearance == .floatingPrimary) {
                $0.fill(.ultraThinMaterial.opacity(titleBackgroundOpacity))
            } else: {
                $0.fill(.clear)
            }
    }

    var secondaryOverlay: some View {
        Rectangle()
            .fill(appearance == .floatingSecondary ? Color.invisibleSolid : Color.clear)
            .multipleGesture(selector.movable ? global.panel.movingGesture(of: panelId) : nil)
            .transaction { $0.animation = nil }
    }
}

// MARK: - HeightControl

private extension FloatingPanelView {
    struct HeightControl: View, TracedView, ComputedSelectorHolder {
        @Environment(\.panelId) var panelId
        @Environment(\.panelAppearance) var appearance

        struct SelectorProps: Equatable { let panelId: UUID }
        class Selector: SelectorBase {
            @Selected({ global.panel.resizable(of: $0.panelId) }) var resizable
            @Selected({ global.panel.resizing == $0.panelId }) var resizing
            @Selected(configs: .init(animation: .fast), { global.panel.style(id: $0.panelId)?.align ?? .topLeading }) var align
        }

        @SelectorWrapper var selector

        var body: some View { trace {
            setupSelector(.init(panelId: panelId)) {
                content
            }
        } }
    }
}

private extension FloatingPanelView.HeightControl {
    var content: some View {
        VStack(spacing: 0) {
            bar
                .opacity(selector.align.isBottom ? 1 : 0)
            Spacer()
            bar
                .opacity(selector.align.isTop ? 1 : 0)
        }
        .frame(maxWidth: .infinity)
        .overlay { indicator }
    }

    var bar: some View {
        RoundedRectangle(cornerSize: .init(squared: 2))
            .fill(appearance == .floatingPrimary ? Color.label.opacity(selector.resizing ? 1 : 0.5) : Color.clear)
            .frame(width: 32, height: 4)
            .padding(4)
            .invisibleSoildOverlay(disabled: appearance != .floatingPrimary)
            .multipleGesture(selector.resizable ? global.panel.resizingGesture(of: panelId) : nil)
            .animation(.fast, value: selector.resizing)
    }

    var indicator: some View {
        GeometryReader {
            RoundedRectangle(cornerSize: .init(squared: 24))
                .stroke(lineWidth: 2)
                .frame(size: $0.frame(in: .global).outset(by: 8).size)
                .offset(-.init(squared: 8))
        }
        .opacity(selector.resizing ? 0.5 : 0)
        .animation(.fast, value: selector.resizing)
    }
}

// MARK: - Switcher

private extension FloatingPanelView {
    struct Switcher: View, TracedView, ComputedSelectorHolder {
        @Environment(\.panelId) var panelId
        @Environment(\.panelAppearance) var appearance

        struct SelectorProps: Equatable { let panelId: UUID }
        class Selector: SelectorBase {
            @Selected({ global.panel.resizable(of: $0.panelId) }) var resizable
            @Selected({ global.panel.resizing == $0.panelId }) var resizing
            @Selected(configs: .init(animation: .fast), { global.panel.style(id: $0.panelId)?.align ?? .topLeading }) var align
        }

        @SelectorWrapper var selector

        var body: some View { trace {
            setupSelector(.init(panelId: panelId)) {
                content
            }
        } }
    }
}

private extension FloatingPanelView.Switcher {
    var content: some View {
        Rectangle()
            .fill(.blue.opacity(0.3))
            .frame(size: .init(squared: 32))
            .innerAligned(.bottomTrailing)
    }
}

// MARK: - FloatingPanelWrapper

struct FloatingPanelWrapper: View, TracedView, EquatableBy, ComputedSelectorHolder {
    let panelId: UUID

    var equatableBy: some Equatable { panelId }

    struct SelectorProps: Equatable { let panelId: UUID }
    class Selector: SelectorBase {
        @Selected({ global.panel.movingOffset(of: $0.panelId) }) var movingOffset
        @Selected({ global.panel.movingEnded(of: $0.panelId) }) var movingEnded
        @Selected({ global.panel.style(id: $0.panelId)?.align ?? .topLeading }) var align
        @Selected(configs: .init(animation: .fast), { global.panel.style(id: $0.panelId)?.padding ?? .zero }) var padding
        @Selected(configs: .init(animation: .fast), { global.panel.style(id: $0.panelId)?.appearance ?? .floatingPrimary }) var appearance
    }

    @SelectorWrapper var selector

    var body: some View { trace {
        setupSelector(.init(panelId: panelId)) {
            content
                .onChange(of: selector.movingEnded) {
                    if selector.movingEnded {
                        global.panel.resetMoving(of: panelId)
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
        if selector.appearance != .floatingHidden {
            FloatingPanelView()
                .environment(\.panelId, panelId)
                .environment(\.panelAppearance, selector.appearance)
                .offset(.init(selector.movingOffset))
                .scaleEffect(scale, anchor: selector.align.unitPoint)
                .rotation3DEffect(rotation, axis: (x: 0, y: 1, z: 0), anchor: selector.align.unitPoint)
                .geometryReader { global.panel.setFrame(of: panelId, $0.frame(in: .global)) }
                .padding(size: selector.padding)
                .offset(.init(secondaryOffset))
                .background { Color.blue.opacity(debugCanvasOverlay ? 0.1 : 0).allowsHitTesting(false) }
                .innerAligned(selector.align)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .geometryReader { global.panel.setRootFrame($0.frame(in: .global)) }
        .background { Color.yellow.opacity(debugCanvasOverlay ? 0.2 : 0).allowsHitTesting(false) }
    }
}
