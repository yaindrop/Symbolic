import SwiftUI

// MARK: - PanelView

struct PanelView: View, TracedView, ComputedSelectorHolder {
    let panel: PanelData

    struct SelectorProps: Equatable { let panelId: UUID }
    class Selector: SelectorBase {
        @Selected({ global.panel.panelFrameMap.value(key: $0.panelId) ?? .zero }) var frame
        @Selected(configs: .init(animation: .normal), { global.panel.appearance(id: $0.panelId) }) var appearance
        @Selected(configs: .init(animation: .fastest), { global.panel.floatingAlign(id: $0.panelId) }) var floatingAlign
        @Selected({ global.panel.floatingHeight(id: $0.panelId) }) var floatingHeight
    }

    @SelectorWrapper var selector

    @State private var titleSize: CGSize = .zero

    @State private var resizing: Bool = false

    @StateObject private var scrollViewModel = ManagedScrollViewModel()

    var body: some View { trace {
        setupSelector(.init(panelId: panel.id)) {
            content
                .id(panel.id)
        }
    } }
}

// MARK: private

private extension PanelView {
    var isPrimary: Bool { selector.appearance == .floatingPrimary }

    var isSecondary: Bool { selector.appearance == .floatingSecondary }

    var isSection: Bool { selector.appearance == .popoverSection }

    @ViewBuilder var content: some View {
        if isSection {
            sectionContent
        } else {
            floatingContent
        }
    }
}

// MARK: popover section

private extension PanelView {
    var sectionContent: some View {
        Section(header: sectionTitle) {
            VStack(spacing: 12) {
                panel.view
            }
            .padding(.leading, 24)
            .padding(.trailing.union(.bottom), 12)
            .environment(\.panelId, panel.id)
        }
    }

    var sectionTitle: some View {
        HStack {
            Text(panel.name)
                .font(.title2)
            Spacer()
            Button {
                global.panel.setFloating(panelId: panel.id)
            } label: {
                Image(systemName: "rectangle.inset.topright.filled")
                    .tint(.label)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipRounded(radius: 12)
        .padding(12)
    }
}

// MARK: floating

private extension PanelView {
    var floatingContent: some View {
        VStack(spacing: 0) {
            title
            scrollView
        }
        .background { background }
        .overlay { floatingTapOverlay }
        .clipRounded(radius: 18)
        .overlay { heightControl }
        .overlay { heightIndicator }
    }

    var title: some View {
        Text(panel.name)
            .font(.headline)
            .padding(.vertical, 8)
            .aligned(axis: .horizontal, .center)
            .padding(.horizontal, 12)
            .invisibleSoildOverlay()
            .multipleGesture(global.panel.floatingPanelDrag(panelId: panel.id))
            .padding(.vertical, 12)
            .background { titleBackground }
            .sizeReader { titleSize = $0 }
    }

    var scrollView: some View {
        ManagedScrollView(model: scrollViewModel) { proxy in
            VStack(spacing: 12) {
                panel.view
            }
            .padding(.all.subtracting(.top), 12)
            .environment(\.panelId, panel.id)
            .environment(\.panelScrollProxy, proxy)
        }
        .scrollBounceBehavior(.basedOnSize, axes: [.vertical])
        .frame(maxWidth: .infinity, maxHeight: max(0, selector.floatingHeight - titleSize.height))
        .fixedSize(horizontal: false, vertical: true)
    }

    var background: some View {
        Rectangle()
            .if(isSecondary) {
                $0.fill(.background.secondary.opacity(0.8))
            } else: {
                $0.fill(.ultraThinMaterial)
            }
    }

    var titleBackground: some View {
        Rectangle()
            .if(selector.appearance == .floatingPrimary && scrollViewModel.scrolled) {
                $0.fill(.ultraThinMaterial)
            } else: {
                $0.fill(.clear)
            }
    }

    func onDragHeightControlBar(y: Scalar) {
        let oppositeY = selector.floatingAlign.isTop ? selector.frame.minY : selector.frame.maxY
        global.panel.onResize(panelId: panel.id, maxHeight: abs(y - oppositeY))
    }

    var heightControlBar: some View {
        RoundedRectangle(cornerSize: .init(squared: 2))
            .fill(isPrimary ? Color.label.opacity(resizing ? 1 : 0.5) : Color.clear)
            .frame(width: 32, height: 4)
            .padding(4)
            .invisibleSoildOverlay(disabled: !isPrimary)
            .multipleGesture(.init(
                configs: .init(coordinateSpace: .global),
                onPress: { resizing = true },
                onPressEnd: { _ in resizing = false },
                onDrag: { onDragHeightControlBar(y: $0.location.y) },
                onDragEnd: { onDragHeightControlBar(y: $0.location.y) }
            ))
            .animation(.fast, value: resizing)
    }

    var heightControl: some View {
        VStack(spacing: 0) {
            heightControlBar
                .opacity(selector.floatingAlign.isBottom ? 1 : 0)
            Spacer()
            heightControlBar
                .opacity(selector.floatingAlign.isTop ? 1 : 0)
        }
    }

    var heightIndicator: some View {
        GeometryReader {
            RoundedRectangle(cornerSize: .init(squared: 24))
                .stroke(lineWidth: 2)
                .frame(size: $0.frame(in: .global).outset(by: 8).size)
                .offset(-.init(squared: 8))
        }
        .opacity(resizing ? 0.5 : 0)
        .animation(.fast, value: resizing)
    }

    var floatingTapOverlay: some View {
        Rectangle()
            .fill(isSecondary ? Color.invisibleSolid : Color.clear)
            .onTapGesture { global.panel.spin(on: panel.id) }
            .transaction { $0.animation = nil }
    }
}
