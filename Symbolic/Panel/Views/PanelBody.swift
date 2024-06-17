import SwiftUI

struct PanelBody<Content: View>: View, TracedView, ComputedSelectorHolder {
    let panelId: UUID, name: String, maxHeight: Scalar
    @ViewBuilder let bodyContent: (ScrollViewProxy) -> Content

    struct SelectorProps: Equatable { let panelId: UUID }
    class Selector: SelectorBase {
        @Selected(animation: .default, { global.panel.floatingState(id: $0.panelId) }) var floatingState
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
        VStack(spacing: 0) {
            title
            ManagedScrollView(model: scrollViewModel) { proxy in
                VStack(spacing: 12) {
                    bodyContent(proxy)
                }
                .padding(.all.subtracting(.top), 12)
            }
            .scrollBounceBehavior(.basedOnSize, axes: [.vertical])
            .frame(maxHeight: maxHeight)
            .fixedSize(horizontal: false, vertical: true)
        }
        .if(selector.floatingState == .primary) {
            $0.background(.ultraThinMaterial)
        } else: {
            $0.background(.background.secondary)
        }
        .clipRounded(radius: 18)
    }

    var title: some View {
        HStack {
            Spacer()
            Text(name)
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.vertical, 8)
            Spacer()
        }
        .padding(12)
        .invisibleSoildOverlay()
        .draggable(panelId.uuidString.data(using: .utf8) ?? .init())
        .multipleGesture(global.panel.moveGesture(panelId: panelId))
        .if(selector.floatingState == .primary && scrollViewModel.scrolled) { $0.background(.regularMaterial) }
    }
}
