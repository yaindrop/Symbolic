import Foundation
import SwiftUI

// MARK: - PanelView

struct PanelView: View {
    let panel: PanelData

    var body: some View { tracer.range("PanelView \(panel.origin)") {
        panel.view(panel.id)
            .sizeReader { global.panel.onResized(panelId: panel.id, size: $0) }
            .offset(x: panel.origin.x, y: panel.origin.y)
            .innerAligned(.topLeading)
    } }
}

// MARK: - PanelRoot

struct PanelRoot: View {
    @Selected var panels = global.panel.panels

    var body: some View {
        ZStack {
            ForEach(panels) { PanelView(panel: $0) }
        }
        .sizeReader { global.panel.onRootResized(size: $0) }
    }
}
