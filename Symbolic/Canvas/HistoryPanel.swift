import Foundation
import SwiftUI

fileprivate extension DocumentEvent {
    var name: String {
        switch action {
        case let .pathAction(pathAction):
            switch pathAction {
            case .load: "PathLoad"
            case let .moveEdge(moveEdge): "\(moveEdge.pathId) MoveEdge \(moveEdge.fromNodeId) offset \(moveEdge.offset)"
            default: "pathAction"
            }
        }
    }
}

// MARK: - HistoryPanel

struct HistoryPanel: View {
    @Environment(\.panelId) private var panelId
    @EnvironmentObject private var panelModel: PanelModel

    var body: some View {
        panel.frame(width: 320)
    }

    // MARK: private

    @Selected private var document = global.document.activeDocument

    @StateObject private var scrollViewModel = ManagedScrollViewModel()

    @State private var moveGesture = PanelModel.moveGestureModel()

    @ViewBuilder private var panel: some View {
        VStack(spacing: 0) {
            PanelTitle(name: "History")
                .if(scrollViewModel.scrolled) { $0.background(.regularMaterial) }
                .invisibleSoildOverlay()
                .multipleGesture(moveGesture, panelModel.idToPanel[panelId], panelModel.moveGestureSetup)
            scrollView
        }
        .background(.regularMaterial)
        .cornerRadius(12)
    }

    @ViewBuilder private var scrollView: some View {
        ManagedScrollView(model: scrollViewModel) { _ in
            content
        }
        .frame(maxHeight: 400)
        .fixedSize(horizontal: false, vertical: true)
        .scrollBounceBehavior(.basedOnSize, axes: [.vertical])
    }

    @ViewBuilder private var content: some View {
        VStack(spacing: 4) {
            PanelSectionTitle(name: "Events")
            VStack(spacing: 12) {
                ForEach(document.events) { e in
                    Text("\(e.name)")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 24)
    }
}
