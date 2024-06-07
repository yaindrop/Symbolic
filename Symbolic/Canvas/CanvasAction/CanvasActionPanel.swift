import SwiftUI

struct CanvasActionPanel: View {
    var body: some View { tracer.range("CanvasActionPanel body") { build {
        WithSelector(selector, .value) {
            VStack(alignment: .leading) {
                if !selector.continuousHints.isEmpty {
                    Text(selector.continuousHints.joined(separator: " "))
                        .padding(8)
                        .background(.green.opacity(0.5))
                        .clipRounded(radius: 12)
                }
                if !selector.triggeringHints.isEmpty {
                    Text(selector.triggeringHints.joined(separator: " "))
                        .padding(8)
                        .background(.orange.opacity(0.5))
                        .clipRounded(radius: 12)
                }
                if !selector.instantHints.isEmpty {
                    Text(selector.instantHints.joined(separator: " "))
                        .padding(8)
                        .background(.blue.opacity(0.5))
                        .clipRounded(radius: 12)
                }
            }
            .font(.footnote)
        }
    } } }

    private class Selector: StoreSelector<Monostate> {
        override var configs: Configs { .init(name: "CanvasActionPanel") }

        @Tracked("triggeringHints", { Array(global.canvasAction.triggering).map { $0.hint } })
        var triggeringHints
        @Tracked("continuousHints", { Array(global.canvasAction.continuous).map { $0.hint } })
        var continuousHints
        @Tracked("instantHints", { Array(global.canvasAction.instant).map { $0.hint } })
        var instantHints
    }

    @StateObject private var selector = Selector()
}
