import SwiftUI

func triggeringHint(_ action: CanvasAction.Triggering) -> String {
    switch action {
    case .addPath: "Hold to add path"
    case .select: "Hold to select"
    case .splitPathEdge: "Hold to split"
    }
}

func continuousHint(_ action: CanvasAction.Continuous) -> String {
    switch action {
    case .panViewport: "Move"
    case .pinchViewport: "Move and scale"
    case .addingPath: "Drag to add path"
    case .pendingSelection: "Drag to select"
    case .splitAndMovePathNode: "Drag to split and move"
    default: "\(action)"
    }
}

struct CanvasActionPanel: View {
    @Selected var triggeringHints = Array(global.canvasAction.triggering).map { triggeringHint($0) }
    @Selected var continuousHints = Array(global.canvasAction.continuous).map { continuousHint($0) }
    @Selected var instantHints = Array(global.canvasAction.instant).map { "\($0)" }

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
