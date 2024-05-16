import Foundation
import SwiftUI

// MARK: - PanelView

struct PanelView: View {
    @EnvironmentObject var model: PanelModel
    var panel: PanelData

    var body: some View {
        panel.view
            .viewSizeReader { model.onResized(panelId: panel.id, size: $0) }
            .offset(x: panel.origin.x, y: panel.origin.y)
            .environment(\.panelId, panel.id)
            .atPlaneAlign(.topLeading)
    }
}

// MARK: - PanelRoot

struct PanelRoot: View {
    @EnvironmentObject var model: PanelModel

    var body: some View {
        ZStack {
            ForEach(model.panels) { PanelView(panel: $0) }
        }
        .viewSizeReader { model.onRootResized(size: $0) }
    }
}
