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
    struct NodePanel: View, EquatableBy, ComputedSelectorHolder {
        struct SelectorProps: Equatable { let nodeId: UUID }
        class Selector: SelectorBase {
            override var configs: Configs { .init(name: "NodePanel") }

            @Selected({ global.activeItem.pathFocusedPart?.nodeId == $0.nodeId }) var focused
        }

        @StateObject var selector = Selector()

        let pathId: UUID
        let nodeId: UUID

        var equatableBy: some Equatable { pathId; nodeId }

        var body: some View { tracer.range("ActivePathPanel NodePanel body") {
            setupSelector(.init(nodeId: nodeId)) {
                content
                    .onChange(of: selector.focused) {
                        withAnimation { expanded = selector.focused }
                    }
            }
        } }

        // MARK: private

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
            .if(selector.focused) { $0.foregroundStyle(.blue) }
        }

        private func updatePosition(pending: Bool = false) -> (Point2) -> Void {
            { global.documentUpdater.update(activePath: .setNodePosition(.init(nodeId: nodeId, position: $0)), pending: pending) }
        }
    }
}

// MARK: - NodeMenu

private extension ActivePathPanel {
    struct NodeMenu<Content: View>: View, EquatableBy, ComputedSelectorHolder {
        struct SelectorProps: Equatable { let pathId: UUID, nodeId: UUID }
        class Selector: SelectorBase {
            override var configs: Configs { .init(name: "NodeMenu") }

            @Selected({ global.path.path(id: $0.pathId)?.mergableNode(id: $0.nodeId) }) var mergableNode
            @Selected({ global.pathProperty.property(id: $0.pathId)?.nodeType(id: $0.nodeId) }) var nodeType
            @Selected({ global.activeItem.pathFocusedPart?.nodeId == $0.nodeId }) var focused
        }

        @StateObject var selector = Selector()

        let pathId: UUID
        let nodeId: UUID
        @ViewBuilder let content: () -> Content

        var equatableBy: some Equatable { pathId; nodeId }

        var body: some View { tracer.range("ActivePathPanel NodeMenu body") {
            setupSelector(.init(pathId: pathId, nodeId: nodeId)) {
                menu
            }
        } }

        // MARK: private

        var menu: some View {
            Menu {
                Label("\(nodeId)", systemImage: "number")

                Button(selector.focused ? "Unfocus" : "Focus", systemImage: selector.focused ? "circle.slash" : "scope") { toggleFocus() }
                if selector.mergableNode != nil {
                    Button("Merge", systemImage: "arrow.triangle.merge", role: .destructive) { mergeNode() }
                }
                Divider()
                ControlGroup {
                    Button("Corner") {
                        global.documentUpdater.update(pathProperty: .update(.init(pathId: pathId, kind: .setNodeType(.init(nodeId: nodeId, nodeType: .corner)))))
                    }
                    .disabled(selector.nodeType == .corner)
                    Button("Locked") {
                        global.documentUpdater.update(pathProperty: .update(.init(pathId: pathId, kind: .setNodeType(.init(nodeId: nodeId, nodeType: .locked)))))
                    }
                    .disabled(selector.nodeType == .locked)
                    Button("Mirrored") {
                        global.documentUpdater.update(pathProperty: .update(.init(pathId: pathId, kind: .setNodeType(.init(nodeId: nodeId, nodeType: .mirrored)))))
                    }
                    .disabled(selector.nodeType == .mirrored)
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
            selector.focused ? global.activeItem.clearFocus() : global.activeItem.setFocus(node: nodeId)
        }

        private func mergeNode() {
            if let mergableNode = selector.mergableNode {
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
    struct NodeDetailPanel: View, EquatableBy, ComputedSelectorHolder {
        struct SelectorProps: Equatable { let pathId: UUID, nodeId: UUID }
        class Selector: SelectorBase {
            override var configs: Configs { .init(name: "NodeDetailPanel") }

            @Selected({ global.path.path(id: $0.pathId)?.pair(before: $0.nodeId) }) var prevPair
            @Selected({ global.path.path(id: $0.pathId)?.node(id: $0.nodeId) }) var node
            @Selected({ global.path.path(id: $0.pathId)?.segment(from: $0.nodeId)?.edge }) var edge
            @Selected({ global.activeItem.pathFocusedPart?.nodeId == $0.nodeId }) var focused
        }

        @StateObject var selector = Selector()

        let pathId: UUID
        let nodeId: UUID

        var equatableBy: some Equatable { pathId; nodeId }

        var body: some View { tracer.range("ActivePathPanel NodeDetailPanel body") {
            setupSelector(.init(pathId: pathId, nodeId: nodeId)) {
                content
                    .onChange(of: self) {}
            }
        } }

        // MARK: private

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
            if let node = selector.node {
                HStack {
                    Text("Position")
                        .font(.callout)
                    Spacer(minLength: 12)
                    PositionPicker(position: node.position) { updatePosition(position: $0, pending: true) } onDone: { updatePosition(position: $0) }
                }
            }
        }

        @ViewBuilder private var cBeforeRow: some View {
            if let prevPair = selector.prevPair {
                Divider()
                HStack {
                    HStack(spacing: 0) {
                        Text("C")
                            .font(.callout.monospaced())
                        Text("Before")
                            .font(.caption2.monospaced())
                            .baselineOffset(-8)
                    }
                    .if(selector.focused) { $0.foregroundStyle(.orange.opacity(0.8)) }
                    Spacer(minLength: 12)
                    PositionPicker(position: Point2(prevPair.edge.control1)) { updatePrevEdge(position: $0, pending: true) } onDone: { updatePrevEdge(position: $0) }
                }
            }
        }

        @ViewBuilder private var cAfterRow: some View {
            if let edge = selector.edge {
                Divider()
                HStack {
                    HStack(spacing: 0) {
                        Text("C")
                            .font(.callout.monospaced())
                        Text("After")
                            .font(.caption2.monospaced())
                            .baselineOffset(-8)
                    }
                    .if(selector.focused) { $0.foregroundStyle(.green.opacity(0.8)) }
                    Spacer(minLength: 12)
                    PositionPicker(position: Point2(edge.control0)) { updateEdge(position: $0, pending: true) } onDone: { updateEdge(position: $0) }
                }
            }
        }

        private func updatePosition(position: Point2, pending: Bool = false) {
            global.documentUpdater.update(activePath: .setNodePosition(.init(nodeId: nodeId, position: position)), pending: pending)
        }

        private func updatePrevEdge(position: Point2, pending: Bool = false) {
            if let prevPair = selector.prevPair {
                global.documentUpdater.update(activePath: .setEdge(.init(fromNodeId: prevPair.node.id, edge: prevPair.edge.with(control0: .init(position)))), pending: pending)
            }
        }

        private func updateEdge(position: Point2, pending: Bool = false) {
            if let edge = selector.edge {
                global.documentUpdater.update(activePath: .setEdge(.init(fromNodeId: nodeId, edge: edge.with(control1: .init(position)))), pending: pending)
            }
        }
    }
}
