import SwiftUI

struct PanelBody<Content: View>: View, TracedView, ComputedSelectorHolder {
    @Environment(\.panelId) var panelId

    let name: String, maxHeight: Scalar
    @ViewBuilder let bodyContent: (ScrollViewProxy) -> Content

    struct SelectorProps: Equatable { let panelId: UUID }
    class Selector: SelectorBase {
        @Selected(animation: .default, { global.panel.appearance(id: $0.panelId) }) var appearance
    }

    @SelectorWrapper var selector

    @StateObject private var scrollViewModel = ManagedScrollViewModel()

    var body: some View { trace {
        setupSelector(.init(panelId: panelId)) {
            content
        }
    } }
}

private extension PanelBody {
    var content: some View {
        VStack(spacing: 12) {
            title
            ManagedScrollView(model: scrollViewModel) { proxy in
                VStack(spacing: 12) {
                    bodyContent(proxy)
                }
            }
            .scrollBounceBehavior(.basedOnSize, axes: [.vertical])
            .frame(maxHeight: maxHeight)
            .fixedSize(horizontal: false, vertical: true)
        }
        .if(selector.appearance == .sidebarSection) {
            $0.padding()
        } else: {
            $0.padding(12)
                .if(selector.appearance == .floatingPrimary) {
                    $0.background(.ultraThinMaterial)
                } else: {
                    $0.background(.background.secondary)
                }
                .clipRounded(radius: 18)
        }
    }

    var title: some View {
        Text(name)
            .font(selector.appearance == .sidebarSection ? .title : .headline)
            .padding(.vertical, 8)
            .aligned(axis: .horizontal, selector.appearance == .sidebarSection ? .start : .center)
            .invisibleSoildOverlay()
            .draggable(panelId.uuidString.data(using: .utf8) ?? .init())
            .multipleGesture(global.panel.moveGesture(panelId: panelId))
            .if(selector.appearance == .floatingPrimary && scrollViewModel.scrolled) { $0.background(.regularMaterial) }
    }
}
