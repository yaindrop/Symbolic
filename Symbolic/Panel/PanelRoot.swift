import Foundation
import SwiftUI

// MARK: - PanelRoot

struct PanelRoot: View {
    @EnvironmentObject var model: PanelModel

    var body: some View {
        ZStack {
            ForEach(model.panels, id: \.id) { panel in
                panel.view
                    .readSize { model.idToPanel[panel.id]?.size = $0 }
                    .offset(x: panel.origin.x, y: panel.origin.y)
                    .zIndex(panel.zIndex)
                    .environment(\.panelId, panel.id)
                    .atPlaneAlign(.topLeading)
                    .onChange(of: panel.size) {
                        print("panel.size", panel.size)
                        guard var panel = model.idToPanel[panel.id] else { return }
                        panel.origin += model.offsetByAffinities(of: panel)
                        withAnimation {
                            model.idToPanel[panel.id] = panel
                        }
                    }
            }
        }
        .readSize { model.rootSize = $0 }
        .onChange(of: model.rootSize) {
            withAnimation {
                print("model.rootSize", model.rootSize)
                for id in model.panelIds {
                    guard var panel = model.idToPanel[id] else { return }
                    panel.origin += model.offsetByAffinities(of: panel)
                    withAnimation {
                        model.idToPanel[panel.id] = panel
                    }
                }
            }
        }
    }
}
