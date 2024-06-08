import Foundation
import SwiftUI

// MARK: - PanelView

struct PanelView: View, EquatableBy {
    let panel: PanelData

    var equatableBy: some Equatable { panel }

    var body: some View { tracer.range("PanelView \(panel.origin)") {
        panel.view(panel.id)
            .id(panel.id)
            .sizeReader { global.panel.onResized(panelId: panel.id, size: $0) }
            .offset(x: panel.origin.x, y: panel.origin.y)
            .innerAligned(.topLeading)
    } }
}

// MARK: - PanelRoot

struct PanelRoot: View, SelectorHolder {
    class Selector: SelectorBase {
        @Selected({ global.panel.panels }) var panels
    }

    @SelectorWrapper var selector

    var body: some View {
        setupSelector {
            ZStack {
                ForEach(selector.panels) { PanelView(panel: $0) }
            }
            .sizeReader { global.panel.onRootResized(size: $0) }
        }
    }
}
