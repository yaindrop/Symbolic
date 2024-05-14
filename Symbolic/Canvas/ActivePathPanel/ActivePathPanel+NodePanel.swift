import Foundation
import SwiftUI

extension ActivePathPanel {
    // MARK: - NodePanel

    struct NodePanel: View, EquatableByTuple {
        let index: Int
        let node: PathNode

        var equatableTuple: some Equatable { index; node }

        @Selected var focused: Bool

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
            _focused = .init { interactor.activePath.focusedNodeId == node.id }
        }

        @ViewBuilder private var title: some View {
            Group {
                Image(systemName: "smallcircle.filled.circle")
                Text("Node \(index)")
                    .font(.subheadline)
            }
            .if(focused) { $0.foregroundStyle(.blue) }
        }

        @ViewBuilder var titleMenu: some View { tracer.range("ActivePathPanel NodePanel titleMenu") {
            memo({ node; focused }) {
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
        } }

        private func updatePosition(pending: Bool = false) -> (Point2) -> Void {
            { interactor.pathUpdater.updateActivePath(node: node.id, position: $0, pending: pending) }
        }

        private func toggleFocus() {
            focused ? interactor.activePath.clearFocus() : interactor.activePath.setFocus(node: node.id)
        }

        private func breakNode() {
            interactor.pathUpdater.updateActivePath(breakAtNode: node.id)
        }

        private func deleteNode() {
            interactor.pathUpdater.updateActivePath(deleteNode: node.id)
        }
    }
}
