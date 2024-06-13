import SwiftUI

// MARK: - NodeRow

extension PathPanel {
    struct NodeRow: View, TracedView, EquatableBy, ComputedSelectorHolder {
        let pathId: UUID, nodeId: UUID

        var equatableBy: some Equatable { pathId; nodeId }

        struct SelectorProps: Equatable { let nodeId: UUID }
        class Selector: SelectorBase {
            @Selected({ global.focusedPath.focusedNodeId == $0.nodeId }) var focused
        }

        @SelectorWrapper var selector

        @State private var expanded = false

        var body: some View { trace {
            setupSelector(.init(nodeId: nodeId)) {
                content
                    .onChange(of: selector.focused) {
                        withAnimation { expanded = selector.focused }
                    }
            }
        } }
    }
}

// MARK: private

private extension PathPanel.NodeRow {
    var content: some View {
        VStack(spacing: 0) {
            HStack {
                Menu { NodeMenu(pathId: pathId, nodeId: nodeId) } label: { name }
                    .menuOrder(.fixed)
                    .tint(.label)
                Spacer()
                expandButton { expandIcon }
            }
            NodeDetailView(pathId: pathId, nodeId: nodeId)
                .padding(12)
                .frame(height: expanded ? nil : 0, alignment: .top)
                .allowsHitTesting(expanded)
                .clipped()
        }
    }

    @ViewBuilder var name: some View {
        HStack {
            Image(systemName: "smallcircle.filled.circle")
            Text("\(nodeId.shortDescription)")
                .font(.subheadline)
        }
        .if(selector.focused) { $0.foregroundStyle(.blue) }
        .padding(12)
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder var expandIcon: some View {
        Image(systemName: expanded ? "chevron.up" : "chevron.down")
            .padding(12)
            .frame(maxHeight: .infinity)
    }

    @ViewBuilder func expandButton<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        Button {
            withAnimation { expanded.toggle() }
        } label: {
            content()
        }
        .tint(.label)
    }

    func updatePosition(pending: Bool = false) -> (Point2) -> Void {
        { global.documentUpdater.update(focusedPath: .setNodePosition(.init(nodeId: nodeId, position: $0)), pending: pending) }
    }
}

// MARK: - NodeMenu

private struct NodeMenu: View, TracedView, EquatableBy, ComputedSelectorHolder {
    let pathId: UUID, nodeId: UUID

    var equatableBy: some Equatable { pathId; nodeId }

    struct SelectorProps: Equatable { let pathId: UUID, nodeId: UUID }
    class Selector: SelectorBase {
        @Formula({ global.path.get(id: $0.pathId) }) static var path
        @Formula({ global.pathProperty.get(id: $0.pathId) }) static var property
        @Selected({ path($0)?.mergableNode(id: $0.nodeId) }) var mergableNode
        @Selected({ property($0)?.nodeType(id: $0.nodeId) }) var nodeType
        @Selected({ global.focusedPath.focusedNodeId == $0.nodeId }) var focused
    }

    @SelectorWrapper var selector

    var body: some View { trace {
        setupSelector(.init(pathId: pathId, nodeId: nodeId)) {
            content
        }
    } }
}

// MARK: private

private extension NodeMenu {
    @ViewBuilder var content: some View {
        Label("\(nodeId)", systemImage: "number")

        Button(selector.focused ? "Unfocus" : "Focus", systemImage: selector.focused ? "circle.slash" : "scope") { toggleFocus() }
        if selector.mergableNode != nil {
            Button("Merge", systemImage: "arrow.triangle.merge", role: .destructive) { mergeNode() }
        }

        Divider()

        ControlGroup { nodeTypeButtons } label: { Text("Node Type") }

        Divider()

        Button("Break", systemImage: "trash.fill", role: .destructive) { breakNode() }
        Button("Delete", systemImage: "trash", role: .destructive) { deleteNode() }
    }

    @ViewBuilder var nodeTypeButtons: some View {
        Button("Corner") { setNodeType(.corner) }
            .disabled(selector.nodeType == .corner)
        Button("Locked") { setNodeType(.locked) }
            .disabled(selector.nodeType == .locked)
        Button("Mirrored") { setNodeType(.mirrored) }
            .disabled(selector.nodeType == .mirrored)
    }

    func toggleFocus() {
        selector.focused ? global.focusedPath.clear() : global.focusedPath.setFocus(node: nodeId)
    }

    func mergeNode() {
        if let mergableNode = selector.mergableNode {
            global.documentUpdater.update(path: .merge(.init(pathId: pathId, endingNodeId: nodeId, mergedPathId: pathId, mergedEndingNodeId: mergableNode.id)))
        }
    }

    func setNodeType(_ nodeType: PathNodeType) {
        global.documentUpdater.update(pathProperty: .update(.init(pathId: pathId, kind: .setNodeType(.init(nodeIds: [nodeId], nodeType: nodeType)))))
    }

    func breakNode() {
        global.documentUpdater.update(path: .breakAtNode(.init(pathId: pathId, nodeId: nodeId, newNodeId: UUID(), newPathId: UUID())))
    }

    func deleteNode() {
        global.documentUpdater.update(focusedPath: .deleteNode(.init(nodeId: nodeId)))
    }
}

// MARK: - NodeDetailPanel

private struct NodeDetailView: View, TracedView, EquatableBy, ComputedSelectorHolder {
    let pathId: UUID, nodeId: UUID

    var equatableBy: some Equatable { pathId; nodeId }

    struct SelectorProps: Equatable { let pathId: UUID, nodeId: UUID }
    class Selector: SelectorBase {
        @Formula({ global.path.get(id: $0.pathId) }) static var path
        @Formula({ global.pathProperty.get(id: $0.pathId) }) static var property
        @Selected({ path($0)?.pair(before: $0.nodeId) }) var prevPair
        @Selected({ path($0)?.node(id: $0.nodeId) }) var node
        @Selected({ path($0)?.segment(from: $0.nodeId)?.edge }) var edge
        @Selected({ global.focusedPath.focusedNodeId == $0.nodeId }) var focused
        @Selected({ property($0)?.edgeType(id: $0.nodeId) }) var edgeType
        @Selected({ props in path(props)?.node(before: props.nodeId).map { property(props)?.edgeType(id: $0.id) } }) var prevEdgeType
    }

    @SelectorWrapper var selector

    var body: some View { trace {
        setupSelector(.init(pathId: pathId, nodeId: nodeId)) {
            content
        }
    } }
}

// MARK: private

private extension NodeDetailView {
    var content: some View {
        VStack(spacing: 12) {
            positionRow
            cBeforeRow
            cAfterRow
        }
        .padding(12)
        .background(.background.secondary)
        .clipRounded(radius: 12)
    }

    @ViewBuilder var positionRow: some View {
        if let node = selector.node {
            HStack {
                Text("Position")
                    .font(.callout)
                Spacer(minLength: 12)
                PositionPicker(position: node.position) { updatePosition(position: $0, pending: true) } onDone: { updatePosition(position: $0) }
            }
        }
    }

    @ViewBuilder var cBeforeRow: some View {
        if let prevEdge = selector.prevPair?.edge, selector.prevEdgeType == .cubic || (selector.prevEdgeType == .auto && prevEdge.control1 != .zero) {
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
                PositionPicker(position: Point2(prevEdge.control1)) { updatePrevEdge(position: $0, pending: true) } onDone: { updatePrevEdge(position: $0) }
            }
        }
    }

    @ViewBuilder var cAfterRow: some View {
        if let edge = selector.edge, selector.edgeType == .cubic || (selector.edgeType == .auto && edge.control0 != .zero) {
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
                .background(.red.opacity(0.4))
                Spacer(minLength: 12)
                PositionPicker(position: Point2(edge.control0)) { updateEdge(position: $0, pending: true) } onDone: { updateEdge(position: $0) }
            }
        }
    }

    func updatePosition(position: Point2, pending: Bool = false) {
        global.documentUpdater.update(focusedPath: .setNodePosition(.init(nodeId: nodeId, position: position)), pending: pending)
    }

    func updatePrevEdge(position: Point2, pending: Bool = false) {
        if let prevPair = selector.prevPair {
            global.documentUpdater.update(focusedPath: .setEdge(.init(fromNodeId: prevPair.node.id, edge: prevPair.edge.with(control0: .init(position)))), pending: pending)
        }
    }

    func updateEdge(position: Point2, pending: Bool = false) {
        if let edge = selector.edge {
            global.documentUpdater.update(focusedPath: .setEdge(.init(fromNodeId: nodeId, edge: edge.with(control1: .init(position)))), pending: pending)
        }
    }
}
