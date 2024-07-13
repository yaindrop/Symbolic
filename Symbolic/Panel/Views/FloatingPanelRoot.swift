import SwiftUI

private let debug: Bool = false

// MARK: - FloatingPanelView

struct FloatingPanelView: View, TracedView, ComputedSelectorHolder {
    @Environment(\.panelId) var panelId
    @Environment(\.panelAppearance) var appearance

    struct SelectorProps: Equatable { let panelId: UUID }
    class Selector: SelectorBase {
        @Selected({ global.panel.get(id: $0.panelId)?.name ?? "" }) var panelName
        @Selected({ global.panel.floatingPanelWidth }) var width
        @Selected({ global.panel.style(id: $0.panelId)?.maxHeight ?? 0 }) var maxHeight
    }

    @SelectorWrapper var selector

    @State private var titleSize: CGSize = .zero

    @StateObject private var scrollViewModel = ManagedScrollViewModel()

    var body: some View { trace {
        setupSelector(.init(panelId: panelId)) {
            content
                .id(panelId)
        }
    } }
}

// MARK: private

private extension FloatingPanelView {
    var content: some View {
        VStack(spacing: 0) {
            title
            scrollView
        }
        .frame(width: selector.width)
        .background { background }
        .overlay { tapOverlay }
        .clipRounded(radius: 18)
        .overlay { HeightControl() }
    }

    @ViewBuilder var title: some View {
        Text(selector.panelName)
            .font(.headline)
            .padding(.vertical, 8)
            .aligned(axis: .horizontal, .center)
            .padding(.horizontal, 12)
            .invisibleSoildOverlay()
            .multipleGesture(global.panel.floatingPanelDrag(panelId: panelId))
            .padding(.vertical, 12)
            .background { titleBackground }
            .sizeReader { titleSize = $0 }
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
        }
        .scrollBounceBehavior(.basedOnSize, axes: [.vertical])
        .frame(maxWidth: .infinity, maxHeight: max(0, selector.maxHeight - titleSize.height))
        .fixedSize(horizontal: false, vertical: true)
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
            .if(appearance == .floatingPrimary && scrollViewModel.scrolled) {
                $0.fill(.ultraThinMaterial)
            } else: {
                $0.fill(.clear)
            }
    }

    var tapOverlay: some View {
        Rectangle()
            .fill(appearance == .floatingSecondary ? Color.invisibleSolid : Color.clear)
            .onTapGesture { global.panel.tap(on: panelId) }
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
            @Selected(configs: .init(animation: .fast), { global.panel.style(id: $0.panelId)?.align ?? .topLeading }) var align
        }

        @SelectorWrapper var selector

        @State private var resizing: Bool = false

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
            .fill(appearance == .floatingPrimary ? Color.label.opacity(resizing ? 1 : 0.5) : Color.clear)
            .frame(width: 32, height: 4)
            .padding(4)
            .invisibleSoildOverlay(disabled: appearance != .floatingPrimary)
            .multipleGesture(.init(
                configs: .init(coordinateSpace: .global),
                onPress: { resizing = true },
                onPressEnd: { _ in resizing = false },
                onDrag: { onDrag(y: $0.location.y) },
                onDragEnd: { onDrag(y: $0.location.y) }
            ))
            .animation(.fast, value: resizing)
    }

    func onDrag(y: Scalar) {
        let frame = global.panel.panelFrameMap.value(key: panelId) ?? .zero
        let oppositeY = selector.align.isTop ? frame.minY : frame.maxY
        global.panel.onResize(panelId: panelId, maxHeight: abs(y - oppositeY))
    }

    var indicator: some View {
        GeometryReader {
            RoundedRectangle(cornerSize: .init(squared: 24))
                .stroke(lineWidth: 2)
                .frame(size: $0.frame(in: .global).outset(by: 8).size)
                .offset(-.init(squared: 8))
        }
        .opacity(resizing ? 0.5 : 0)
        .animation(.fast, value: resizing)
    }
}

// MARK: - FloatingPanelWrapper

struct FloatingPanelWrapper: View, TracedView, EquatableBy, ComputedSelectorHolder {
    let panelId: UUID

    var equatableBy: some Equatable { panelId }

    struct SelectorProps: Equatable { let panelId: UUID }
    class Selector: SelectorBase {
        @Selected({ global.panel.moving(id: $0.panelId)?.offset ?? .zero }) var offset
        @Selected({ global.panel.moving(id: $0.panelId)?.ended ?? false }) var ended
        @Selected({ global.panel.style(id: $0.panelId)?.align ?? .topLeading }) var align
        @Selected(configs: .init(animation: .fast), { global.panel.style(id: $0.panelId)?.padding ?? .zero }) var padding
        @Selected(configs: .init(animation: .fast), { global.panel.style(id: $0.panelId)?.appearance ?? .floatingPrimary }) var appearance
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
        FloatingPanelView()
            .environment(\.panelId, panelId)
            .environment(\.panelAppearance, selector.appearance)
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
