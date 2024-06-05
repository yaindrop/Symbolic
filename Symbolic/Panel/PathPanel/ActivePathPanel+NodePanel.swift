import Foundation
import SwiftUI

extension ActivePathPanel {
    // MARK: - NodePanel

    struct NodePanel: View, EquatableBy {
        let path: Path
        let property: PathProperty
        let focusedPart: PathFocusedPart?

        let index: Int
        let node: PathNode

        private var focused: Bool { focusedPart?.nodeId == node.id }
        private var nodeType: PathNodeType { property.nodeType(id: node.id) }

        var equatableBy: some Equatable { index; node; focused; nodeType }

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
                    ControlGroup {
                        Button("Corner") {
                            global.documentUpdater.update(pathProperty: .update(.init(pathId: path.id, kind: .setNodeType(.init(nodeId: node.id, nodeType: .corner)))))
                        }
                        .disabled(nodeType == .corner)
                        Button("Locked") {
                            global.documentUpdater.update(pathProperty: .update(.init(pathId: path.id, kind: .setNodeType(.init(nodeId: node.id, nodeType: .locked)))))
                        }
                        .disabled(nodeType == .locked)
                        Button("Mirrored") {
                            global.documentUpdater.update(pathProperty: .update(.init(pathId: path.id, kind: .setNodeType(.init(nodeId: node.id, nodeType: .mirrored)))))
                        }
                        .disabled(nodeType == .mirrored)
                    } label: {
                        Text("Node Type")
                    }
                    Divider()
                    Button("Break", systemImage: "trash.fill", role: .destructive) { breakNode() }
                    Button("Delete", systemImage: "trash", role: .destructive) { deleteNode() }
                } label: {
                    title
                }
                .tint(.label)
            } deps: { node; focused; nodeType }
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
