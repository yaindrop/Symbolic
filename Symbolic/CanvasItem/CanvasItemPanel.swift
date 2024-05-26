import Foundation
import SwiftUI

fileprivate extension DocumentEvent {
    var name: String {
        switch action {
        case let .pathAction(pathAction):
            switch pathAction {
            case .load: "PathLoad"
            case let .single(single):
                switch single.kind {
                case let .moveEdge(moveEdge): "\(single.pathId) MoveEdge \(moveEdge.fromNodeId) offset \(moveEdge.offset)"
                default: "single pathAction"
                }
            default: "pathAction"
            }
        }
    }
}

// MARK: - CanvasItemPanel

struct CanvasItemPanel: View {
    @Environment(\.panelId) private var panelId
    @EnvironmentObject private var panelModel: PanelModel

    var body: some View {
        panel.frame(width: 320)
    }

    // MARK: private

    @Selected private var items = global.canvasItem.items

    @StateObject private var scrollViewModel = ManagedScrollViewModel()

    @State private var moveGesture = PanelModel.moveGestureModel()

    @ViewBuilder private var panel: some View {
        VStack(spacing: 0) {
            PanelTitle(name: "Items")
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
            PanelSectionTitle(name: "Items")
            VStack(spacing: 12) {
                ForEach(items) { e in
                    Text("\(e)")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 24)
    }
}
