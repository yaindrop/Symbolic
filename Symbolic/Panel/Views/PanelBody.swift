import SwiftUI

// MARK: - PanelBody

struct PanelBody<Content: View>: View, TracedView, ComputedSelectorHolder {
    @Environment(\.panelId) var panelId

    let name: String
    @ViewBuilder let bodyContent: (ScrollViewProxy?) -> Content

    struct SelectorProps: Equatable { let panelId: UUID }
    class Selector: SelectorBase {
        @Selected(configs: .init(animation: .normal), { global.panel.appearance(id: $0.panelId) }) var appearance
        @Selected(configs: .init(animation: .fastest), { global.panel.floatingAlign(id: $0.panelId) }) var floatingAlign
        @Selected({ global.panel.floatingHeight(id: $0.panelId) }) var floatingHeight
    }

    @SelectorWrapper var selector

    @State private var titleSize: CGSize = .zero
    @State private var bodyFrame: CGRect = .zero

    @State private var originY: Scalar?

    @StateObject private var scrollViewModel = ManagedScrollViewModel()

    var body: some View { trace {
        setupSelector(.init(panelId: panelId)) {
            content
                .id(panelId)
        }
    } }
}

// MARK: private

private extension PanelBody {
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

private extension PanelBody {
    var sectionContent: some View {
        Section(header: sectionTitle) {
            VStack(spacing: 12) {
                bodyContent(nil)
            }
            .padding(.leading, 24)
            .padding(.trailing.union(.bottom), 12)
        }
    }

    var sectionTitle: some View {
        HStack {
            Text(name)
                .font(.title2)
            Spacer()
            Button {
                global.panel.setFloating(panelId: panelId)
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

private extension PanelBody {
    var floatingContent: some View {
        VStack(spacing: 0) {
            title
                .sizeReader { titleSize = $0 }
            ManagedScrollView(model: scrollViewModel) { proxy in
                VStack(spacing: 12) {
                    bodyContent(proxy)
                }
                .padding(.all.subtracting(.top), 12)
            }
            .scrollBounceBehavior(.basedOnSize, axes: [.vertical])
            .frame(maxWidth: .infinity, maxHeight: max(0, selector.floatingHeight - titleSize.height))
            .fixedSize(horizontal: false, vertical: true)
        }
        .geometryReader { bodyFrame = $0.frame(in: .global) }
        .background { background }
        .overlay { floatingTapOverlay }
        .clipRounded(radius: 18)
        .overlay { heightControl }
        .overlay { heightIndicator }
    }

    var title: some View {
        Text(name)
            .font(.headline)
            .padding(.vertical, 8)
            .aligned(axis: .horizontal, .center)
            .padding(.horizontal, 12)
            .invisibleSoildOverlay()
            .multipleGesture(global.panel.floatingPanelDrag(panelId: panelId))
            .padding(.vertical, 12)
            .background { titleBackground }
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

    var draggingHeightControl: Bool { originY != nil }

    func onDragHeightControlBar(y: Scalar) {
        if let originY {
            global.panel.onTargetHeight(panelId: panelId, height: abs(y - originY))
        }
    }

    var heightControlBar: some View {
        RoundedRectangle(cornerSize: .init(squared: 2))
            .fill(isPrimary ? Color.label.opacity(draggingHeightControl ? 1 : 0.5) : Color.clear)
            .frame(width: 32, height: 4)
            .padding(4)
            .invisibleSoildOverlay(disabled: !isPrimary)
            .multipleGesture(.init(
                configs: .init(coordinateSpace: .global),
                onPress: { originY = selector.floatingAlign.isTop ? bodyFrame.minY : bodyFrame.maxY },
                onPressEnd: { _ in originY = nil },
                onDrag: { onDragHeightControlBar(y: $0.location.y) },
                onDragEnd: { onDragHeightControlBar(y: $0.location.y) }
            ))
            .animation(.fast, value: draggingHeightControl)
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
        .opacity(draggingHeightControl ? 1 : 0)
        .animation(.fast, value: draggingHeightControl)
    }

    var floatingTapOverlay: some View {
        Rectangle()
            .fill(isSecondary ? Color.invisibleSolid : Color.clear)
            .onTapGesture { global.panel.spin(on: panelId) }
            .transaction { $0.animation = nil }
    }
}
