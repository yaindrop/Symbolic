import SwiftUI

struct PanelBody<Content: View>: View, TracedView, ComputedSelectorHolder {
    @Environment(\.panelId) var panelId

    let name: String, maxHeight: Scalar
    @ViewBuilder let bodyContent: (ScrollViewProxy?) -> Content

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

struct VisualEffectView: UIViewRepresentable {
    let effect: UIVisualEffect
    func makeUIView(context _: Context) -> UIVisualEffectView { .init(effect: effect) }
    func updateUIView(_: UIViewType, context _: Context) {}
}

private extension PanelBody {
    @ViewBuilder var content: some View {
        if selector.appearance == .popoverSection {
            Section(header: sectionTitle) {
                VStack(spacing: 12) {
                    bodyContent(nil)
                }
                .padding(.leading, 24)
                .padding(.trailing.union(.bottom), 12)
            }
        } else {
            VStack(spacing: 12) {
                floatingTitle
                ManagedScrollView(model: scrollViewModel) { proxy in
                    VStack(spacing: 12) {
                        bodyContent(proxy)
                    }
                }
                .scrollBounceBehavior(.basedOnSize, axes: [.vertical])
                .frame(maxHeight: maxHeight)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .if(selector.appearance == .floatingSecondary) {
                $0.background(.background.secondary)
                    .invisibleSoildOverlay()
                    .multipleGesture(global.panel.floatingPanelDrag(panelId: panelId))
            } else: {
                $0.background(.ultraThinMaterial)
            }
            .clipRounded(radius: 18)
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
        .draggable(panelId.uuidString.data(using: .utf8) ?? .init())
        .padding(12)
    }

    var floatingTitle: some View {
        Text(name)
            .font(.headline)
            .padding(.vertical, 8)
            .aligned(axis: .horizontal, .center)
            .invisibleSoildOverlay()
            .multipleGesture(global.panel.floatingPanelDrag(panelId: panelId))
            .if(selector.appearance == .floatingPrimary && scrollViewModel.scrolled) { $0.background(.ultraThinMaterial) }
    }
}
