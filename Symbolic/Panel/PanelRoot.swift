import Foundation
import SwiftUI

// MARK: - PanelView

struct PanelView: View {
    @EnvironmentObject var model: PanelModel
    var panel: PanelData

    var body: some View {
        panel.view
            .sizeReader { model.onResized(panelId: panel.id, size: $0) }
            .offset(x: panel.origin.x, y: panel.origin.y)
            .environment(\.panelId, panel.id)
            .innerAligned(.topLeading)
    }
}

// MARK: - PanelRoot

struct PanelRoot: View {
    @EnvironmentObject var model: PanelModel

    var body: some View {
        ZStack {
            ForEach(model.panels) { PanelView(panel: $0) }
        }
        .sizeReader { model.onRootResized(size: $0) }
    }
}
