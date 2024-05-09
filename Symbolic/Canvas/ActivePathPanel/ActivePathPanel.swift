import Foundation
import SwiftUI

import SwiftUI

// MARK: - ActivePathPanel

struct ActivePathPanel: View {
    var body: some View {
        panel.frame(width: 320)
    }

    // MARK: private

    @EnvironmentObject private var pathStore: PathStore
    @EnvironmentObject private var activePathModel: ActivePathModel

    @StateObject private var scrollViewModel = ManagedScrollViewModel()

    @Environment(\.panelId) private var panelId
    @EnvironmentObject private var panelModel: PanelModel

    @ViewBuilder private var panel: some View {
        VStack(spacing: 0) {
            PanelTitle(name: "Active Path")
                .if(scrollViewModel.scrolled) { $0.background(.regularMaterial) }
                .invisibleSoildOverlay()
                .modifier(panelModel.moveGesture(panelId: panelId))
            scrollView
        }
        .background(.regularMaterial)
        .cornerRadius(12)
    }

    @ViewBuilder private var scrollView: some View {
        if let activePath = activePathModel.pendingActivePath {
            ManagedScrollView(model: scrollViewModel) { proxy in
                Components(activePath: activePath).id(activePath.id)
                    .onChange(of: activePathModel.focusedPart) {
                        guard let id = activePathModel.focusedPart?.id else { return }
                        withAnimation(.easeInOut(duration: 0.2)) { proxy.scrollTo(id, anchor: .center) }
                    }
            }
            .frame(maxHeight: 400)
            .fixedSize(horizontal: false, vertical: true)
            .scrollBounceBehavior(.basedOnSize, axes: [.vertical])
        }
    }
}
