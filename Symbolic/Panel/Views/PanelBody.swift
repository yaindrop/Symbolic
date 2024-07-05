import SwiftUI

// MARK: - PanelBody

struct PanelBody<Content: View>: View, TracedView, ComputedSelectorHolder {
    @Environment(\.panelId) var panelId

    let name: String, maxHeight: Scalar
    @ViewBuilder let bodyContent: (ScrollViewProxy?) -> Content

    struct SelectorProps: Equatable { let panelId: UUID }
    class Selector: SelectorBase {
        @Selected(configs: .init(animation: .normal), { global.panel.appearance(id: $0.panelId) }) var appearance
    }

    @SelectorWrapper var selector

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
    @ViewBuilder var content: some View {
        if selector.appearance == .popoverSection {
            sectionBody
        } else {
            floatingBody
        }
    }

    var sectionBody: some View {
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

    var isSecondary: Bool { selector.appearance == .floatingSecondary }

    var floatingBody: some View {
        VStack(spacing: 0) {
            floatingTitle
            ManagedScrollView(model: scrollViewModel) { proxy in
                VStack(spacing: 12) {
                    bodyContent(proxy)
                }
                .padding(.all.subtracting(.top), 12)
            }
            .scrollBounceBehavior(.basedOnSize, axes: [.vertical])
            .frame(maxWidth: .infinity, maxHeight: maxHeight)
            .fixedSize(horizontal: false, vertical: true)
        }
        .background {
            Rectangle()
                .if(isSecondary) {
                    $0.fill(.background.secondary.opacity(0.8))
                } else: {
                    $0.fill(.ultraThinMaterial)
                }
        }
        .overlay {
            Rectangle()
                .fill(isSecondary ? Color.invisibleSolid : Color.clear)
                .onTapGesture { global.panel.spin(on: panelId) }
                .transaction { $0.animation = nil }
        }
        .clipRounded(radius: 18)
    }

    var floatingTitle: some View {
        Text(name)
            .font(.headline)
            .padding(.vertical, 8)
            .aligned(axis: .horizontal, .center)
            .padding(12)
            .invisibleSoildOverlay()
            .multipleGesture(global.panel.floatingPanelDrag(panelId: panelId))
            .background {
                Rectangle()
                    .if(selector.appearance == .floatingPrimary && scrollViewModel.scrolled) {
                        $0.fill(.ultraThinMaterial)
                    } else: {
                        $0.fill(.clear)
                    }
            }
    }
}
