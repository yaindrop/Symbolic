import Foundation
import SwiftUI

// MARK: - PanelView

struct PanelView: View, TracedView, EquatableBy {
    let panel: PanelData

    var equatableBy: some Equatable { panel }

    var body: some View { trace {
        panel.view(panel.id)
            .id(panel.id)
            .sizeReader { global.panel.onResized(panelId: panel.id, size: $0) }
            .offset(x: panel.origin.x, y: panel.origin.y)
            .innerAligned(.topLeading)
    } }
}

// MARK: - PanelRoot

struct PanelRoot: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        @Selected({ global.panel.panels }) var panels
    }

    @SelectorWrapper var selector

    var body: some View { trace {
        setupSelector {
            ZStack {
                ForEach(selector.panels) { PanelView(panel: $0) }
            }
            .sizeReader { global.panel.onRootResized(size: $0) }
        }
    } }
}
