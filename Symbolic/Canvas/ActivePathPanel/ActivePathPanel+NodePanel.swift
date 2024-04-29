import Foundation
import SwiftUI

extension ActivePathPanel {
    // MARK: - NodePanel

    struct NodePanel: View {
        let index: Int
        let node: PathNode

        var body: some View {
            HStack {
                Image(systemName: "smallcircle.filled.circle")
                Text("\(index)")
                    .font(.headline)
                Spacer()
                PositionPicker(position: node.position, onChange: updatePosition(pending: true), onDone: updatePosition())
            }
            .padding(12)
            .background(.ultraThickMaterial)
            .cornerRadius(12)
        }

        @EnvironmentObject private var updater: PathUpdater

        private func updatePosition(pending: Bool = false) -> (Point2) -> Void {
            { updater.updateActivePath(node: node.id, position: $0, pending: pending) }
        }
    }
}
