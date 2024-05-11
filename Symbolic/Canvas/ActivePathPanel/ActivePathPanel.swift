import Foundation
import SwiftUI

import SwiftUI

// MARK: - ActivePathPanel

struct ActivePathPanel: View {
    var body: some View {
        panel.frame(width: 320)
    }

    // MARK: private

    @EnvironmentObject private var viewport: ViewportModel
    @EnvironmentObject private var pathModel: PathModel
    @EnvironmentObject private var activePathModel: ActivePathModel
    private var activePath: ActivePathInteractor { .init(pathModel, activePathModel) }

    @EnvironmentObject private var pathUpdateModel: PathUpdateModel
    private var updater: PathUpdater { .init(viewport, pathModel, activePathModel, pathUpdateModel) }

    @StateObject private var scrollViewModel = ManagedScrollViewModel()

    @Environment(\.panelId) private var panelId
    @EnvironmentObject private var panelModel: PanelModel

    @StateObject var moveGesture = PanelModel.moveGestureModel()

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
        if let pendingActivePath = activePath.pendingActivePath {
            ManagedScrollView(model: scrollViewModel) { proxy in
                Components(activePath: pendingActivePath).id(pendingActivePath.id)
                    .onChange(of: activePath.focusedPart) {
                        guard let id = activePath.focusedPart?.id else { return }
                        withAnimation(.easeInOut(duration: 0.2)) { proxy.scrollTo(id, anchor: .center) }
                    }
            }
            .frame(maxHeight: 400)
            .fixedSize(horizontal: false, vertical: true)
            .scrollBounceBehavior(.basedOnSize, axes: [.vertical])
        }
    }
}
