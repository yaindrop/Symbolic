import Foundation
import SwiftUI

// MARK: - ActivePathPanel

struct ActivePathPanel: View {
    @Environment(\.panelId) private var panelId
    @EnvironmentObject private var panelModel: PanelModel

    var body: some View { tracer.range("ActivePathPanel body") {
        panel.frame(width: 320)
    }}

    // MARK: private

    @Selected private var activePath = service.activePath.pendingActivePath

    @StateObject private var scrollViewModel = ManagedScrollViewModel()

    @State private var moveGesture = PanelModel.moveGestureModel()

    @ViewBuilder private var panel: some View {
        VStack(spacing: 0) {
            PanelTitle(name: "Active Path")
                .if(scrollViewModel.scrolled) { $0.background(.regularMaterial) }
                .invisibleSoildOverlay()
                .multipleGesture(moveGesture, panelModel.idToPanel[panelId], panelModel.moveGestureSetup)
            scrollView
        }
        .background(.regularMaterial)
        .cornerRadius(12)
    }

    @ViewBuilder private var scrollView: some View {
        if let activePath {
            ManagedScrollView(model: scrollViewModel) { proxy in
                Components(activePath: activePath).id(activePath.id)
                    .onChange(of: service.activePath.focusedPart) {
                        guard let id = service.activePath.focusedPart?.id else { return }
                        withAnimation(.easeInOut(duration: 0.2)) { proxy.scrollTo(id, anchor: .center) }
                    }
            }
            .frame(maxHeight: 400)
            .fixedSize(horizontal: false, vertical: true)
            .scrollBounceBehavior(.basedOnSize, axes: [.vertical])
        }
    }
}
