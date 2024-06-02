import Foundation
import SwiftUI

extension ActivePathPanel {
    // MARK: - NodePanel

    struct NodePanel: View, EquatableBy {
        let path: Path
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
            .clipRounded(radius: 12)
        }}

        init(path: Path, index: Int, node: PathNode) {
            self.path = path
            self.index = index
            self.node = node
            _focused = .init { global.activeItem.pathFocusedPart?.nodeId == node.id }
        }

        @Selected private var focused: Bool

        private var mergableNode: PathNode? {
            path.mergableNode(id: node.id)
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
            Memo {
                Menu {
                    Label("\(node.id)", systemImage: "number")
                    Button(focused ? "Unfocus" : "Focus", systemImage: focused ? "circle.slash" : "scope") { toggleFocus() }
                    if mergableNode != nil {
                        Button("Merge", systemImage: "arrow.triangle.merge", role: .destructive) { mergeNode() }
                    }
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
            { global.documentUpdater.update(activePath: .setNodePosition(.init(nodeId: node.id, position: $0)), pending: pending) }
        }

        private func toggleFocus() {
            focused ? global.activeItem.clearFocus() : global.activeItem.setFocus(node: node.id)
        }

        private func mergeNode() {
            if let mergableNode {
                global.documentUpdater.update(path: .merge(.init(pathId: path.id, endingNodeId: node.id, mergedPathId: path.id, mergedEndingNodeId: mergableNode.id)))
            }
        }

        private func breakNode() {
            if let activePathId = global.activeItem.focusedItemId {
                global.documentUpdater.update(path: .breakAtNode(.init(pathId: activePathId, nodeId: node.id, newNodeId: UUID(), newPathId: UUID())))
            }
        }

        private func deleteNode() {
            global.documentUpdater.update(activePath: .deleteNode(.init(nodeId: node.id)))
        }
    }
}
