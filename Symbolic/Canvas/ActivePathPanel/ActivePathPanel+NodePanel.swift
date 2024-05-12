import Foundation
import SwiftUI

extension ActivePathPanel {
    // MARK: - NodePanel

    struct NodePanel: View, EnablePathUpdater, EnablePathInteractor, EnableActivePathInteractor {
        @EnvironmentObject var viewport: ViewportModel
        @EnvironmentObject var pathModel: PathModel
        @EnvironmentObject var pendingPathModel: PendingPathModel
        @EnvironmentObject var activePathModel: ActivePathModel
        @EnvironmentObject var pathUpdateModel: PathUpdateModel

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

        private var focused: Bool { activePathInteractor.focusedPart == .node(node.id) }

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
            .tint(.label)
        }

        private func updatePosition(pending: Bool = false) -> (Point2) -> Void {
            { pathUpdater.updateActivePath(node: node.id, position: $0, pending: pending) }
        }

        private func toggleFocus() {
            focused ? activePathInteractor.clearFocus() : activePathInteractor.setFocus(node: node.id)
        }

        private func breakNode() {
            pathUpdater.updateActivePath(breakAtNode: node.id)
        }

        private func deleteNode() {
            pathUpdater.updateActivePath(deleteNode: node.id)
        }
    }
}
