import Foundation
import SwiftUI

extension ActivePathPanel {
    // MARK: - NodePanel

    struct NodePanel: View, EquatableBy {
        let index: Int
        let node: PathNode

        var equatableBy: some Equatable { index; node }

        var body: some View { tracer.range("ActivePathPanel NodePanel body") {
            HStack {
                titleMenu
                Spacer()
                PositionPicker(position: node.position, onChange: updatePosition(pending: true), onDone: updatePosition())
            }
            .padding(12)
            .background(.ultraThickMaterial)
            .cornerRadius(12)
        }}

        init(index: Int, node: PathNode) {
            self.index = index
            self.node = node
            _focused = .init { global.activePath.focusedPart?.nodeId == node.id }
        }

        @Selected private var focused: Bool

        @ViewBuilder private var title: some View {
            Group {
                Image(systemName: "smallcircle.filled.circle")
                Text("Node \(index)")
                    .font(.subheadline)
            }
            .if(focused) { $0.foregroundStyle(.blue) }
        }

        @ViewBuilder var titleMenu: some View { tracer.range("ActivePathPanel NodePanel titleMenu") {
            Memo {
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
            } deps: { node; focused }
        } }

        private func updatePosition(pending: Bool = false) -> (Point2) -> Void {
            { global.pathUpdater.updateActivePath(node: node.id, position: $0, pending: pending) }
        }

        private func toggleFocus() {
            focused ? global.activePath.clearFocus() : global.activePath.setFocus(node: node.id)
        }

        private func breakNode() {
            global.pathUpdater.updateActivePath(breakAtNode: node.id)
        }

        private func deleteNode() {
            global.pathUpdater.updateActivePath(deleteNode: node.id)
        }
    }
}
