import SwiftUI

struct CanvasActionPanel: View {
    @Selected var triggeringHints = Array(global.canvasAction.triggering).map { $0.hint }
    @Selected var continuousHints = Array(global.canvasAction.continuous).map { $0.hint }
    @Selected var instantHints = Array(global.canvasAction.instant).map { $0.hint }

    var body: some View {
        VStack(alignment: .leading) {
            if !continuousHints.isEmpty {
                Text(continuousHints.joined(separator: " "))
                    .padding(8)
                    .background(.green.opacity(0.5))
                    .cornerRadius(12)
            }
            if !triggeringHints.isEmpty {
                Text(triggeringHints.joined(separator: " "))
                    .padding(8)
                    .background(.orange.opacity(0.5))
                    .cornerRadius(12)
            }
            if !instantHints.isEmpty {
                Text(instantHints.joined(separator: " "))
                    .padding(8)
                    .background(.blue.opacity(0.5))
                    .cornerRadius(12)
            }
        }
        .font(.footnote)
    }
}
