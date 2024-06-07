import Foundation
import SwiftUI

// MARK: - ActivePathPanel

struct ActivePathPanel: View {
    let panelId: UUID

    var body: some View { tracer.range("ActivePathPanel body") {
        panel.frame(width: 320)
    }}

    // MARK: private

    @Selected private var path = global.activeItem.activePath
    @Selected private var focusedPart = global.activeItem.store.pathFocusedPart

    @StateObject private var scrollViewModel = ManagedScrollViewModel()

    @ViewBuilder private var panel: some View {
        VStack(spacing: 0) {
            PanelTitle(name: "Active Path")
                .if(scrollViewModel.scrolled) { $0.background(.regularMaterial) }
                .invisibleSoildOverlay()
                .multipleGesture(global.panel.moveGesture(panelId: panelId))
            scrollView
        }
        .background(.ultraThinMaterial)
        .clipRounded(radius: 12)
    }

    @ViewBuilder private var scrollView: some View {
        if let path {
            ManagedScrollView(model: scrollViewModel) { proxy in
                Nodes(path: path).id(path.id)
                    .onChange(of: focusedPart) {
                        guard let id = focusedPart?.id else { return }
                        withAnimation(.easeInOut(duration: 0.2)) { proxy.scrollTo(id, anchor: .center) }
                    }
            }
            .frame(maxHeight: 400)
            .fixedSize(horizontal: false, vertical: true)
            .scrollBounceBehavior(.basedOnSize, axes: [.vertical])
        }
    }
}
