import Foundation
import SwiftUI

extension ActivePathPanel {
    // MARK: - NodePanel

    struct NodePanel: View {
        let index: Int
        let node: PathNode

        var body: some View {
            HStack {
                titleMenu
                Spacer()
                PositionPicker(position: node.position, onChange: updatePosition(pending: true), onDone: updatePosition())
            }
            .padding(12)
            .background(.ultraThickMaterial)
            .cornerRadius(12)
        }

        @EnvironmentObject private var activePathModel: ActivePathModel
        @EnvironmentObject private var updater: PathUpdater

        private var focused: Bool { activePathModel.focusedPart == .node(node.id) }

        @ViewBuilder private var title: some View {
            Group {
                Image(systemName: "smallcircle.filled.circle")
                Text("Node \(index)")
                    .font(.subheadline)
            }
            .if(focused) { $0.foregroundStyle(.blue) }
        }

        @ViewBuilder var titleMenu: some View {
            Menu {
                Label("\(node.id)", systemImage: "number")
                Button(focused ? "Unfocus" : "Focus", systemImage: focused ? "circle.slash" : "scope") { toggleFocus() }
                Divider()
                Button("Break", systemImage: "trash.fill", role: .destructive) { breakNode() }
                Button("Delete", systemImage: "trash", role: .destructive) { deleteNode() }
            } label: {
                title
            }
            .buttonStyle(PlainButtonStyle())
        }

        private func updatePosition(pending: Bool = false) -> (Point2) -> Void {
            { updater.updateActivePath(node: node.id, position: $0, pending: pending) }
        }

        private func toggleFocus() {
            focused ? activePathModel.clearFocus() : activePathModel.setFocus(node: node.id)
        }

        private func breakNode() {
            updater.updateActivePath(breakAtNode: node.id)
        }

        private func deleteNode() {
            updater.updateActivePath(deleteNode: node.id)
        }
    }
}
