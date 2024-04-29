import Foundation
import SwiftUI

struct ActivePathPanelNodePanel: View {
    let index: Int
    let node: PathNode

    var body: some View {
        HStack {
            Image(systemName: "smallcircle.filled.circle")
            Text("\(index)")
                .font(.headline)
            Spacer()
            PositionPicker(position: node.position) {
                updater.updateActivePath(node: node.id, position: $0, pending: true)
            } onDone: {
                updater.updateActivePath(node: node.id, position: $0)
            }
        }
        .padding(12)
        .background(.ultraThickMaterial)
        .cornerRadius(12)
    }

    @EnvironmentObject private var updater: PathUpdater
}
