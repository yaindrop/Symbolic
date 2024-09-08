import SwiftUI

// MARK: - FloatingPanelView

struct FloatingPanelView: View, TracedView, ComputedSelectorHolder {
    @Environment(\.panelId) var panelId
    @Environment(\.panelFloatingStyle) var floatingStyle

    struct SelectorProps: Equatable { let panelId: UUID }
    class Selector: SelectorBase {
        @Selected({ global.panel.get(id: $0.panelId)?.name ?? "" }) var panelName
        @Selected({ global.panel.floatingWidth }) var width
        @Selected({ global.panel.maxHeight(of: $0.panelId) }) var maxHeight
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
        .overlay { ResizeHandle() }
        .overlay { SwitchHandle() }
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
            .if(floatingStyle.isPrimary) {
                $0.fill(.ultraThinMaterial)
            } else: {
                $0.fill(.background.secondary.opacity(0.8))
            }
    }

    var titleBackground: some View {
        Rectangle()
            .if(floatingStyle.isPrimary) {
                $0.fill(.ultraThinMaterial.opacity(titleBackgroundOpacity))
            } else: {
                $0.fill(.clear)
            }
    }

    var secondaryOverlay: some View {
        Rectangle()
            .fill(floatingStyle.isPrimary ? Color.clear : Color.invisibleSolid)
            .multipleGesture(selector.movable ? global.panel.movingGesture(of: panelId) : nil)
            .transaction { $0.animation = nil }
    }
}

// MARK: - ResizeHandle

private extension FloatingPanelView {
    struct ResizeHandle: View, TracedView, ComputedSelectorHolder {
        @Environment(\.panelId) var panelId
        @Environment(\.panelFloatingStyle) var floatingStyle

        struct SelectorProps: Equatable { let panelId: UUID }
        class Selector: SelectorBase {
            @Selected({ global.panel.resizable(of: $0.panelId) }) var resizable
            @Selected({ global.panel.resizing == $0.panelId }) var resizing
            @Selected(configs: .init(animation: .fast), { global.panel.align(of: $0.panelId) }) var align
        }

        @SelectorWrapper var selector

        var body: some View { trace {
            setupSelector(.init(panelId: panelId)) {
                content
            }
        } }
    }
}

private extension FloatingPanelView.ResizeHandle {
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
            .fill(selector.resizing ? Color.blue : Color.label.opacity(0.3))
            .frame(width: 32, height: 4)
            .padding(4)
            .invisibleSoildOverlay()
            .multipleGesture(selector.resizable ? global.panel.resizingGesture(of: panelId) : nil)
            .animation(.fast, value: selector.resizing)
            .opacity(floatingStyle.isPrimary ? 1 : 0)
    }

    var indicator: some View {
        GeometryReader {
            RoundedRectangle(cornerSize: .init(squared: 24))
                .stroke(.blue, lineWidth: 2)
                .frame(size: $0.frame(in: .global).outset(by: 8).size)
                .offset(-.init(squared: 8))
        }
        .opacity(selector.resizing ? 0.5 : 0)
        .animation(.fast, value: selector.resizing)
    }
}

// MARK: - SwitchHandle

private extension FloatingPanelView {
    struct SwitchHandle: View, TracedView, ComputedSelectorHolder {
        @Environment(\.panelId) var panelId
        @Environment(\.panelFloatingStyle) var floatingStyle

        struct SelectorProps: Equatable { let panelId: UUID }
        class Selector: SelectorBase {
            @Selected({ global.panel.switching?.id == $0.panelId }) var switching
            @Selected(configs: .init(animation: .fast), { global.panel.align(of: $0.panelId) }) var align
        }

        @SelectorWrapper var selector

        var body: some View { trace {
            setupSelector(.init(panelId: panelId)) {
                content
            }
        } }
    }
}

private extension FloatingPanelView.SwitchHandle {
    @ViewBuilder var content: some View {
        let align = selector.align.flipped(axis: .vertical)
        Circle()
            .fill(selector.switching ? Color.blue : Color.label.opacity(0.3))
            .mask {
                ZStack {
                    Rectangle()
                    Image(systemName: "ellipsis")
                        .font(.footnote)
                        .blendMode(.destinationOut)
                }
            }
            .frame(size: .init(squared: 24))
            .padding(6)
            .invisibleSoildOverlay()
            .multipleGesture(global.panel.switchingGesture(of: panelId))
            .animation(.fast, value: selector.switching)
            .innerAligned(align)
            .opacity(floatingStyle.isPrimary ? 1 : 0)
    }
}

// MARK: - FloatingPanelWrapper

struct FloatingPanelWrapper: View, TracedView, EquatableBy, ComputedSelectorHolder {
    let panelId: UUID

    var equatableBy: some Equatable { panelId }

    struct SelectorProps: Equatable { let panelId: UUID }
    class Selector: SelectorBase {
        @Selected(configs: .init(animation: .fast), { global.panel.floatingStyle(of: $0.panelId) }) var floatingStyle
        @Selected({ global.panel.moving(of: $0.panelId) }) var moving
        @Selected({ global.panel.floatingPadding }) var padding
    }

    @SelectorWrapper var selector

    var body: some View { trace {
        setupSelector(.init(panelId: panelId)) {
            content
                .onChange(of: selector.moving?.ended ?? false) { _, ended in
                    if ended {
                        global.panel.resetMoving(of: panelId)
                    }
                }
        }
    } }
}

// MARK: private

private extension FloatingPanelWrapper {
    @ViewBuilder var content: some View {
        if let style = selector.floatingStyle {
            FloatingPanelView()
                .environment(\.panelId, panelId)
                .environment(\.panelFloatingStyle, style)
                .offset(selector.moving?.offset ?? .zero)
                .rotation3DEffect(style.rotation3DAngle, axis: style.rotation3DAxis, anchor: style.rotation3DAnchor)
                .scaleEffect(style.scale, anchor: style.scaleAnchor)
                .offset(style.offset)
                .geometryReader { global.panel.setFrame(of: panelId, $0.frame(in: .global)) }
                .background { Color.blue.opacity(debugCanvasOverlay ? 0.1 : 0).allowsHitTesting(false) }
                .padding(size: selector.padding)
                .innerAligned(style.align)
                .opacity(style.opacity)
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
