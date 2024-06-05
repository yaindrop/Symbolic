import SwiftUI

struct CanvasActionPanel: View {
    @Listened(name: "triggeringHints") var triggeringHints = Array(global.canvasAction.triggering).map { $0.hint }
    @Listened(name: "continuousHints") var continuousHints = Array(global.canvasAction.continuous).map { $0.hint }
    @Listened(name: "instantHints") var instantHints = Array(global.canvasAction.instant).map { $0.hint }

    var body: some View { tracer.range("CanvasActionPanel body") { build {
        VStack(alignment: .leading) {
            if !continuousHints.isEmpty {
                Text(continuousHints.joined(separator: " "))
                    .padding(8)
                    .background(.green.opacity(0.5))
                    .clipRounded(radius: 12)
            }
            if !triggeringHints.isEmpty {
                Text(triggeringHints.joined(separator: " "))
                    .padding(8)
                    .background(.orange.opacity(0.5))
                    .clipRounded(radius: 12)
            }
            if !instantHints.isEmpty {
                Text(instantHints.joined(separator: " "))
                    .padding(8)
                    .background(.blue.opacity(0.5))
                    .clipRounded(radius: 12)
            }
        }
        .font(.footnote)
        .onReceive($triggeringHints) { _triggeringHints.value = $0 }
        .onReceive($continuousHints) { _continuousHints.value = $0 }
        .onReceive($instantHints) { _instantHints.value = $0 }
    } } }
}
