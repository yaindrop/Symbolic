import Foundation
import SwiftUI

// MARK: - ActivePathPanel

struct ActivePathPanel: View, EnablePathInteractor, EnableActivePathInteractor {
    @EnvironmentObject var pathModel: PathModel
    @EnvironmentObject var pendingPathModel: PendingPathModel
    @EnvironmentObject var activePathModel: ActivePathModel

    @Environment(\.panelId) private var panelId
    @EnvironmentObject private var panelModel: PanelModel

    var body: some View {
        panel.frame(width: 320)
    }

    // MARK: private

    @StateObject private var scrollViewModel = ManagedScrollViewModel()

    @StateObject private var moveGesture = PanelModel.moveGestureModel()

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
        if let pendingActivePath = activePathInteractor.pendingActivePath {
            ManagedScrollView(model: scrollViewModel) { proxy in
                Components(activePath: pendingActivePath).id(pendingActivePath.id)
                    .onChange(of: activePathInteractor.focusedPart) {
                        guard let id = activePathInteractor.focusedPart?.id else { return }
                        withAnimation(.easeInOut(duration: 0.2)) { proxy.scrollTo(id, anchor: .center) }
                    }
            }
            .frame(maxHeight: 400)
            .fixedSize(horizontal: false, vertical: true)
            .scrollBounceBehavior(.basedOnSize, axes: [.vertical])
        }
    }
}
