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
                Button { toggleFocus() } label: { name }
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

    func toggleFocus() {
        selector.focused ? global.focusedPath.clear() : global.focusedPath.setFocus(node: nodeId)
    }

    func updatePosition(pending: Bool = false) -> (Point2) -> Void {
        { global.documentUpdater.update(focusedPath: .setNodePosition(.init(nodeId: nodeId, position: $0)), pending: pending) }
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
        @Selected({ path($0)?.pair(id: $0.nodeId) }) var pair
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
        VStack(spacing: 0) {
            prevEdgeRow
            positionRow
            edgeRow
        }
        .background(.background.secondary)
        .clipRounded(radius: 12)
    }

    @ViewBuilder var positionRow: some View {
        if let node = selector.pair?.node {
            Divider()
            HStack {
                Menu { NodeMenu(pathId: pathId, nodeId: nodeId) } label: {
                    Text("Node")
                        .font(.callout)
                        .padding(12)
                }
                .menuOrder(.fixed)
                .tint(.label)
                .if(selector.focused) { $0.foregroundStyle(.blue.opacity(0.8)) }
                Spacer(minLength: 12)
                PositionPicker(position: node.position) { updatePosition(position: $0, pending: true) } onDone: { updatePosition(position: $0) }
                    .padding(12)
            }
        }
    }

    @ViewBuilder var prevEdgeRow: some View {
        if let prevPair = selector.prevPair {
            let prevNode = prevPair.node, prevEdge = prevPair.edge
            let isCubic = selector.prevEdgeType == .cubic || (selector.prevEdgeType == .auto && prevEdge.control1 != .zero)
            let isLine = selector.prevEdgeType == .line || (selector.prevEdgeType == .auto && prevEdge.control1 == .zero)
            HStack {
                let menu = EdgeMenu(pathId: pathId, fromNodeId: prevNode.id)
                if isCubic {
                    Menu { menu } label: { rowTitle(name: "Cubic", subname: "Before") }
                        .menuOrder(.fixed)
                        .tint(.label)
                        .if(selector.focused) { $0.foregroundStyle(.orange.opacity(0.8)) }
                } else if isLine {
                    Menu { menu } label: { rowTitle(name: "Line", subname: "Before") }
                        .menuOrder(.fixed)
                        .tint(.label)
                }
                Spacer(minLength: 12)
                if isCubic {
                    PositionPicker(position: Point2(prevEdge.control1)) { updatePrevEdge(position: $0, pending: true) } onDone: { updatePrevEdge(position: $0) }
                        .padding(12)
                }
            }
        }
    }

    @ViewBuilder var edgeRow: some View {
        if let pair = selector.pair {
            let node = pair.node, edge = pair.edge
            let isCubic = selector.edgeType == .cubic || (selector.edgeType == .auto && edge.control0 != .zero)
            let isLine = selector.edgeType == .line || (selector.edgeType == .auto && edge.control0 == .zero)
            Divider()
            HStack {
                let menu = EdgeMenu(pathId: pathId, fromNodeId: node.id)
                if isCubic {
                    Menu { menu } label: { rowTitle(name: "Cubic", subname: "After") }
                        .menuOrder(.fixed)
                        .tint(.label)
                        .if(selector.focused) { $0.foregroundStyle(.green.opacity(0.8)) }
                } else if isLine {
                    Menu { menu } label: { rowTitle(name: "Line", subname: "After") }
                        .menuOrder(.fixed)
                        .tint(.label)
                }
                Spacer(minLength: 12)
                if isCubic {
                    PositionPicker(position: Point2(edge.control0)) { updateEdge(position: $0, pending: true) } onDone: { updateEdge(position: $0) }
                        .padding(12)
                }
            }
        }
    }

    func rowTitle(name: String, subname: String) -> some View {
        HStack(spacing: 0) {
            Text(name)
                .font(.callout)
            Text(subname)
                .font(.caption2)
                .baselineOffset(-8)
        }
        .padding(12)
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
        if let edge = selector.pair?.edge {
            global.documentUpdater.update(focusedPath: .setEdge(.init(fromNodeId: nodeId, edge: edge.with(control1: .init(position)))), pending: pending)
        }
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

        Button("Break", systemImage: "scissors.circle", role: .destructive) { breakNode() }
        Button("Delete", systemImage: "trash", role: .destructive) { deleteNode() }
    }

    @ViewBuilder var nodeTypeButtons: some View {
        nodeTypeButton(.corner)
        nodeTypeButton(.locked)
        nodeTypeButton(.mirrored)
    }

    @ViewBuilder func nodeTypeButton(_ nodeType: PathNodeType) -> some View {
        var name: String {
            switch nodeType {
            case .corner: "Corner"
            case .locked: "Locked"
            case .mirrored: "Mirrored"
            }
        }
        let selected = selector.nodeType == nodeType
        Button(name, systemImage: selected ? "checkmark" : "") { setNodeType(nodeType) }
            .disabled(selected)
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

// MARK: - EdgeMenu

private struct EdgeMenu: View, TracedView, EquatableBy, ComputedSelectorHolder {
    let pathId: UUID, fromNodeId: UUID

    var equatableBy: some Equatable { pathId; fromNodeId }

    struct SelectorProps: Equatable { let pathId: UUID, fromNodeId: UUID }
    class Selector: SelectorBase {
        @Formula({ global.path.get(id: $0.pathId) }) static var path
        @Formula({ global.pathProperty.get(id: $0.pathId) }) static var property
        @Selected({ path($0)?.segment(from: $0.fromNodeId) }) var segment
        @Selected({ property($0)?.edgeType(id: $0.fromNodeId) }) var edgeType
        @Selected({ global.focusedPath.focusedSegmentId == $0.fromNodeId }) var focused
    }

    @SelectorWrapper var selector

    var body: some View { trace {
        setupSelector(.init(pathId: pathId, fromNodeId: fromNodeId)) {
            content
        }
    } }
}

// MARK: private

private extension EdgeMenu {
    @ViewBuilder var content: some View {
        Label("\(fromNodeId)", systemImage: "number")
        Button(selector.focused ? "Unfocus" : "Focus", systemImage: selector.focused ? "circle.slash" : "scope") { toggleFocus() }

        Divider()

        ControlGroup { edgeTypeButtons } label: { Text("Edge Type") }

        Divider()

        Button("Split", systemImage: "square.and.line.vertical.and.square") { splitEdge() }

        Divider()

        Button("Break", systemImage: "scissors.circle", role: .destructive) { breakEdge() }
    }

    @ViewBuilder var edgeTypeButtons: some View {
        edgeTypeButton(.line)
        edgeTypeButton(.cubic)
        edgeTypeButton(.quadratic)
    }

    @ViewBuilder func edgeTypeButton(_ edgeType: PathEdgeType) -> some View {
        var name: String {
            switch edgeType {
            case .line: "Line"
            case .cubic: "Cubic Bezier"
            case .quadratic: "Quadratic Bezier"
            case .auto: ""
            }
        }
        let selected = selector.edgeType == edgeType
        Button(name, systemImage: selected ? "checkmark" : "") { selected ? setEdgeType(.auto) : setEdgeType(edgeType) }
    }

    func toggleFocus() {
        selector.focused ? global.focusedPath.clear() : global.focusedPath.setFocus(segment: fromNodeId)
    }

    func setEdgeType(_ edgeType: PathEdgeType) {
        global.documentUpdater.update(pathProperty: .update(.init(pathId: pathId, kind: .setEdgeType(.init(fromNodeIds: [fromNodeId], edgeType: edgeType)))))
    }

    func splitEdge() {
        guard let segment = selector.segment else { return }
        let paramT = segment.tessellated().approxPathParamT(lineParamT: 0.5).t
        let id = UUID()
        global.documentUpdater.update(focusedPath: .splitSegment(.init(fromNodeId: fromNodeId, paramT: paramT, newNodeId: id, offset: .zero)))
        global.focusedPath.setFocus(node: id)
    }

    func breakEdge() {
        if let pathId = global.activeItem.focusedItemId {
            global.documentUpdater.update(path: .breakAtEdge(.init(pathId: pathId, fromNodeId: fromNodeId, newPathId: UUID())))
        }
    }
}
