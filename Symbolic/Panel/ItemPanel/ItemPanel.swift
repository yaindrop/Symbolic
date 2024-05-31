import Foundation
import SwiftUI

// MARK: - ItemPanel

struct ItemPanel: View {
    @Environment(\.panelId) private var panelId
    @EnvironmentObject private var panelModel: PanelModel

    var body: some View {
        panel.frame(width: 320)
    }

    // MARK: private

    @Selected private var allItems = global.item.rootItems

    @StateObject private var scrollViewModel = ManagedScrollViewModel()

    @ViewBuilder private var panel: some View {
        VStack(spacing: 0) {
            PanelTitle(name: "Items")
                .if(scrollViewModel.scrolled) { $0.background(.regularMaterial) }
                .invisibleSoildOverlay()
                .multipleGesture(panelModel.moveGesture(panelId: panelId))
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
                ForEach(allItems) { e in
                    Text("\(e)")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 24)
    }
}
