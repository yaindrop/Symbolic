import Foundation
import SwiftUI

// MARK: - Nodes

extension ActivePathPanel {
    struct Nodes: View {
        let path: Path

        @ViewBuilder var body: some View { tracer.range("ActivePathPanel Nodes body") {
            VStack(spacing: 4) {
                PanelSectionTitle(name: "Nodes")
                VStack(spacing: 0) {
                    ForEach(path.nodes) { node in
                        NodePanel(pathId: path.id, nodeId: node.id)
                        if node.id != path.nodes.last?.id {
                            Divider()
                        }
                    }
                }
                .background(.ultraThickMaterial)
                .clipRounded(radius: 12)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 24)
        }}
    }
}

// MARK: - NodePanel

extension ActivePathPanel {
    struct NodePanel: View, EquatableBy {
        let pathId: UUID
        let nodeId: UUID

        var equatableBy: some Equatable { pathId; nodeId }

        var body: some View { tracer.range("ActivePathPanel NodePanel body") {
            content
                .compute(_focused, nodeId)
                .onChange(of: focused) {
                    withAnimation { expanded = focused }
                }
        } }

        // MARK: private

        @Computed({ (nodeId: UUID) in global.activeItem.pathFocusedPart?.nodeId == nodeId })
        private var focused: Bool = false

        private var content: some View {
            VStack {
                HStack {
                    NodeMenu(pathId: pathId, nodeId: nodeId) { title }
                    Spacer()
                    expandButton
                }
                NodeDetailPanel(pathId: pathId, nodeId: nodeId)
                    .padding(.top, 12)
                    .frame(height: expanded ? nil : 0, alignment: .top)
                    .allowsHitTesting(expanded)
                    .clipped()
            }
            .padding(12)
        }

        @State private var expanded = false

        @ViewBuilder private var expandButton: some View {
            Button {
                withAnimation { expanded.toggle() }
            } label: {
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .padding(6)
            }
            .tint(.label)
        }

        @ViewBuilder private var title: some View {
            Group {
                Image(systemName: "smallcircle.filled.circle")
                Text("\(nodeId.shortDescription)")
                    .font(.subheadline)
            }
            .if(focused) { $0.foregroundStyle(.blue) }
        }

        private func updatePosition(pending: Bool = false) -> (Point2) -> Void {
            { global.documentUpdater.update(activePath: .setNodePosition(.init(nodeId: nodeId, position: $0)), pending: pending) }
        }
    }
}

// MARK: - NodeMenu

private extension ActivePathPanel {
    struct NodeMenu<Content: View>: View, EquatableBy {
        let pathId: UUID
        let nodeId: UUID
        @ViewBuilder let content: () -> Content

        var equatableBy: some Equatable { pathId; nodeId }

        var body: some View { tracer.range("ActivePathPanel NodeMenu body") {
            menu
                .compute(_mergableNode, (pathId, nodeId))
                .compute(_nodeType, (pathId, nodeId))
                .compute(_focused, nodeId)
        } }

        // MARK: private

        @Computed({ (pathId: UUID, nodeId: UUID) in global.path.path(id: pathId)?.mergableNode(id: nodeId) })
        private var mergableNode: PathNode? = nil

        @Computed({ (pathId: UUID, nodeId: UUID) in global.pathProperty.property(id: pathId)?.nodeType(id: nodeId) })
        private var nodeType: PathNodeType? = nil

        @Computed({ (nodeId: UUID) in global.activeItem.pathFocusedPart?.nodeId == nodeId })
        private var focused: Bool = false

        var menu: some View {
            Menu {
                Label("\(nodeId)", systemImage: "number")

                Button(focused ? "Unfocus" : "Focus", systemImage: focused ? "circle.slash" : "scope") { toggleFocus() }
                if mergableNode != nil {
                    Button("Merge", systemImage: "arrow.triangle.merge", role: .destructive) { mergeNode() }
                }
                Divider()
                ControlGroup {
                    Button("Corner") {
                        global.documentUpdater.update(pathProperty: .update(.init(pathId: pathId, kind: .setNodeType(.init(nodeId: nodeId, nodeType: .corner)))))
                    }
                    .disabled(nodeType == .corner)
                    Button("Locked") {
                        global.documentUpdater.update(pathProperty: .update(.init(pathId: pathId, kind: .setNodeType(.init(nodeId: nodeId, nodeType: .locked)))))
                    }
                    .disabled(nodeType == .locked)
                    Button("Mirrored") {
                        global.documentUpdater.update(pathProperty: .update(.init(pathId: pathId, kind: .setNodeType(.init(nodeId: nodeId, nodeType: .mirrored)))))
                    }
                    .disabled(nodeType == .mirrored)
                } label: {
                    Text("Node Type")
                }
                Divider()
                Button("Break", systemImage: "trash.fill", role: .destructive) { breakNode() }
                Button("Delete", systemImage: "trash", role: .destructive) { deleteNode() }
            } label: {
                content()
            }
            .tint(.label)
        }

        private func toggleFocus() {
            focused ? global.activeItem.clearFocus() : global.activeItem.setFocus(node: nodeId)
        }

        private func mergeNode() {
            if let mergableNode {
                global.documentUpdater.update(path: .merge(.init(pathId: pathId, endingNodeId: nodeId, mergedPathId: pathId, mergedEndingNodeId: mergableNode.id)))
            }
        }

        private func breakNode() {
            global.documentUpdater.update(path: .breakAtNode(.init(pathId: pathId, nodeId: nodeId, newNodeId: UUID(), newPathId: UUID())))
        }

        private func deleteNode() {
            global.documentUpdater.update(activePath: .deleteNode(.init(nodeId: nodeId)))
        }
    }
}

// MARK: - NodeDetailPanel

private extension ActivePathPanel {
    struct NodeDetailPanel: View, EquatableBy {
        let pathId: UUID
        let nodeId: UUID

        var equatableBy: some Equatable { pathId; nodeId }

        var body: some View { tracer.range("ActivePathPanel NodeDetailPanel body") {
            content
                .compute(_prevPair, (pathId, nodeId))
                .compute(_node, (pathId, nodeId))
                .compute(_edge, (pathId, nodeId))
                .compute(_focused, nodeId)
        } }

        // MARK: private

        @Computed({ (pathId: UUID, nodeId: UUID) in global.path.path(id: pathId)?.pair(before: nodeId) })
        private var prevPair: Path.NodeEdgePair? = nil

        @Computed({ (pathId: UUID, nodeId: UUID) in global.path.path(id: pathId)?.node(id: nodeId) })
        private var node: PathNode? = nil

        @Computed({ (pathId: UUID, nodeId: UUID) in global.path.path(id: pathId)?.segment(from: nodeId)?.edge })
        private var edge: PathEdge? = nil

        @Computed({ (nodeId: UUID) in global.activeItem.pathFocusedPart?.nodeId == nodeId })
        private var focused: Bool = false

        private var content: some View {
            VStack(spacing: 12) {
                positionRow
                cBeforeRow
                cAfterRow
            }
            .padding(12)
            .background(.tertiary)
            .clipRounded(radius: 12)
        }

        @ViewBuilder private var positionRow: some View {
            if let node {
                HStack {
                    Text("Position")
                        .font(.callout)
                    Spacer(minLength: 12)
                    PositionPicker(position: node.position) { updatePosition(position: $0, pending: true) } onDone: { updatePosition(position: $0) }
                }
            }
        }

        @ViewBuilder private var cBeforeRow: some View {
            if let prevPair {
                Divider()
                HStack {
                    HStack(spacing: 0) {
                        Text("C")
                            .font(.callout.monospaced())
                        Text("Before")
                            .font(.caption2.monospaced())
                            .baselineOffset(-8)
                    }
                    .if(focused) { $0.foregroundStyle(.orange.opacity(0.8)) }
                    Spacer(minLength: 12)
                    PositionPicker(position: Point2(prevPair.edge.control1)) { updatePrevEdge(position: $0, pending: true) } onDone: { updatePrevEdge(position: $0) }
                }
            }
        }

        @ViewBuilder private var cAfterRow: some View {
            if let edge {
                Divider()
                HStack {
                    HStack(spacing: 0) {
                        Text("C")
                            .font(.callout.monospaced())
                        Text("After")
                            .font(.caption2.monospaced())
                            .baselineOffset(-8)
                    }
                    .if(focused) { $0.foregroundStyle(.green.opacity(0.8)) }
                    Spacer(minLength: 12)
                    PositionPicker(position: Point2(edge.control0)) { updateEdge(position: $0, pending: true) } onDone: { updateEdge(position: $0) }
                }
            }
        }

        private func updatePosition(position: Point2, pending: Bool = false) {
            global.documentUpdater.update(activePath: .setNodePosition(.init(nodeId: nodeId, position: position)), pending: pending)
        }

        private func updatePrevEdge(position: Point2, pending: Bool = false) {
            if let prevPair {
                global.documentUpdater.update(activePath: .setEdge(.init(fromNodeId: prevPair.node.id, edge: prevPair.edge.with(control0: .init(position)))), pending: pending)
            }
        }

        private func updateEdge(position: Point2, pending: Bool = false) {
            if let edge {
                global.documentUpdater.update(activePath: .setEdge(.init(fromNodeId: nodeId, edge: edge.with(control1: .init(position)))), pending: pending)
            }
        }
    }
}
