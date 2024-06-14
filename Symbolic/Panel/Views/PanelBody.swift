import SwiftUI

struct PanelTitle: View {
    let panelId: UUID, name: String

    var body: some View {
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
    }
}

struct PanelBody<Content: View>: View {
    let panelId: UUID, name: String, maxHeight: Scalar
    @ViewBuilder let content: (ScrollViewProxy) -> Content

    @StateObject private var scrollViewModel = ManagedScrollViewModel()

    var body: some View {
        VStack(spacing: 0) {
            PanelTitle(panelId: panelId, name: name)
                .if(scrollViewModel.scrolled) { $0.background(.regularMaterial) }
            ManagedScrollView(model: scrollViewModel) { proxy in
                VStack(spacing: 12) {
                    content(proxy)
                }
                .padding(.all.subtracting(.top), 12)
            }
            .scrollBounceBehavior(.basedOnSize, axes: [.vertical])
            .frame(maxHeight: maxHeight)
            .fixedSize(horizontal: false, vertical: true)
        }
        .background(.ultraThinMaterial)
        .clipRounded(radius: 18)
    }
}
