import SwiftUI

private struct Context {
    var path: Path
    var pathProperty: PathProperty
    var focusedNodeId: UUID?
}

// MARK: - Nodes

extension PathPanel {
    struct Nodes: View, ComputedSelectorHolder {
        let pathId: UUID

        struct SelectorProps: Equatable { let pathId: UUID }
        class Selector: SelectorBase {
            @Selected({ global.path.get(id: $0.pathId) }) var path
            @Selected({ global.pathProperty.get(id: $0.pathId) }) var pathProperty
            @Selected({ global.focusedPath.focusedNodeId }) var focusedNodeId
        }

        @SelectorWrapper var selector

        var body: some View {
            setupSelector(.init(pathId: pathId)) {
                content
            }
        }
    }
}

// MARK: private

private extension PathPanel.Nodes {
    @ViewBuilder var content: some View {
        if let context {
            let nodeIds = context.path.nodeIds
            LazyVStack(spacing: 0) {
                ForEach(nodeIds) { nodeId in
                    NodeRow(context: context, nodeId: nodeId)
                    if nodeId != nodeIds.last {
                        Divider().padding(.leading, 12)
                    }
                }
            }
        }
    }

    var context: Context? {
        if let path = selector.path, let pathProperty = selector.pathProperty {
            .init(path: path, pathProperty: pathProperty, focusedNodeId: selector.focusedNodeId)
        } else {
            nil
        }
    }
}

// MARK: - NodeRow

private struct NodeRow: View, TracedView {
    let context: Context, nodeId: UUID

    @State private var expanded = false

    var body: some View { trace {
        content
    } }
}

// MARK: private

private extension NodeRow {
    var content: some View {
        VStack(spacing: 0) {
            row
            NodeDetailView(context: context, nodeId: nodeId)
                .padding(12)
                .frame(height: expanded ? nil : 0, alignment: .top)
                .allowsHitTesting(expanded)
                .clipped()
        }
        .onChange(of: focused) {
            withAnimation { expanded = focused }
        }
    }

    var focused: Bool { context.focusedNodeId == nodeId }

    @ViewBuilder var row: some View {
        HStack {
            Button { toggleFocus() } label: { name }
                .tint(.label)
            Spacer()
            expandButton
        }
    }

    @ViewBuilder var name: some View {
        Memo {
            HStack {
                Image(systemName: "smallcircle.filled.circle")
                Text("\(nodeId.shortDescription)")
                    .font(.subheadline)
            }
            .foregroundStyle(focused ? .blue : .label)
            .padding(12)
            .frame(maxHeight: .infinity)
        } deps: { nodeId; focused }
    }

    @ViewBuilder var expandButton: some View {
        Memo {
            Button {
                withAnimation { expanded.toggle() }
            } label: {
                expandIcon
            }
            .tint(.label)
        } deps: { expanded }
    }

    @ViewBuilder var expandIcon: some View {
        Image(systemName: expanded ? "chevron.up" : "chevron.down")
            .padding(12)
            .frame(maxHeight: .infinity)
    }

    func toggleFocus() {
        focused ? global.focusedPath.clear() : global.focusedPath.setFocus(node: nodeId)
    }
}

// MARK: - NodeDetailPanel

private struct NodeDetailView: View, TracedView {
    let context: Context, nodeId: UUID

    var body: some View { trace {
        content
    } }
}

// MARK: private

private extension NodeDetailView {
    var content: some View {
        VStack(spacing: 0) {
            controlInRow
            positionRow
            controlOutRow
        }
        .background(.background.secondary)
        .clipRounded(radius: 12)
    }

    var node: PathNode? { context.path.node(id: nodeId) }

    var focused: Bool { context.focusedNodeId == nodeId }

    var segmentType: PathSegmentType? { context.pathProperty.segmentType(id: nodeId) }

    var prevSegmentType: PathSegmentType? { context.path.nodeId(before: nodeId).map { context.pathProperty.segmentType(id: $0) }}

    @ViewBuilder var positionRow: some View {
        if let node {
            Divider()
            HStack {
                Menu { NodeMenu(context: context, nodeId: nodeId) } label: {
                    Text("Node")
                        .font(.callout)
                        .padding(12)
                }
                .menuOrder(.fixed)
                .tint(.label)
                .foregroundStyle(focused ? .blue.opacity(0.8) : .label)
                Spacer(minLength: 12)
                PositionPicker(position: node.position) { updateNode(position: $0, pending: true) } onDone: { updateNode(position: $0) }
                    .padding(12)
            }
        }
    }

    @ViewBuilder var controlInRow: some View {
        if let node = node {
            let segmentType = prevSegmentType
            let isCubic = segmentType == .cubic || (segmentType == .auto && node.controlIn != .zero)
            let isLine = segmentType == .line || (segmentType == .auto && node.controlIn == .zero)
            HStack {
                let menu = EmptyView()
                if isCubic {
                    rowTitle(name: "Cubic", subname: "In")
                        .foregroundStyle(focused ? .orange.opacity(0.8) : .label)
                } else if isLine {
                    rowTitle(name: "Line", subname: "In")
                        .tint(.label)
                }
                Spacer(minLength: 12)
                if isCubic {
                    PositionPicker(position: Point2(node.controlIn)) { updateNode(controlIn: .init($0), pending: true) } onDone: { updateNode(controlIn: .init($0)) }
                        .padding(12)
                }
            }
        }
    }

    @ViewBuilder var controlOutRow: some View {
        if let node = node {
            let segmentType = segmentType
            let isCubic = segmentType == .cubic || (segmentType == .auto && node.controlOut != .zero)
            let isLine = segmentType == .line || (segmentType == .auto && node.controlOut == .zero)
            Divider()
            HStack {
                if isCubic {
                    rowTitle(name: "Cubic", subname: "Out")
                        .foregroundStyle(focused ? .green.opacity(0.8) : .label)
                } else if isLine {
                    rowTitle(name: "Line", subname: "Out")
                        .tint(.label)
                }
                Spacer(minLength: 12)
                if isCubic {
                    PositionPicker(position: Point2(node.controlOut)) { updateNode(controlOut: .init($0), pending: true) } onDone: { updateNode(controlOut: .init($0)) }
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

    func updateNode(position: Point2? = nil, controlIn: Vector2? = nil, controlOut: Vector2? = nil, pending: Bool = false) {
        if var node {
            position.map { node.position = $0 }
            controlIn.map { node.controlIn = $0 }
            controlOut.map { node.controlOut = $0 }
            global.documentUpdater.update(focusedPath: .setNode(.init(nodeId: nodeId, node: node)), pending: pending)
        }
    }
}

// MARK: - NodeMenu

private struct NodeMenu: View, TracedView {
    let context: Context, nodeId: UUID

    var body: some View { trace {
        content

    } }
}

// MARK: private

private extension NodeMenu {
    @ViewBuilder var content: some View {
        Label("\(nodeId)", systemImage: "number")

        Button(focused ? "Unfocus" : "Focus", systemImage: focused ? "circle.slash" : "scope") { toggleFocus() }
        if mergableNodeId != nil {
            Button("Merge", systemImage: "arrow.triangle.merge", role: .destructive) { mergeNode() }
        }

        Divider()

        ControlGroup { nodeTypeButtons } label: { Text("Node Type") }

        Divider()

        Button("Break", systemImage: "scissors.circle", role: .destructive) { breakNode() }
        Button("Delete", systemImage: "trash", role: .destructive) { deleteNode() }
    }

    var mergableNodeId: UUID? { context.path.mergableNodeId(id: nodeId) }

    var nodeType: PathNodeType? { context.pathProperty.nodeType(id: nodeId) }

    var focused: Bool { context.focusedNodeId == nodeId }

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
        let selected = self.nodeType == nodeType
        Button(name, systemImage: selected ? "checkmark" : "") { setNodeType(nodeType) }
            .disabled(selected)
    }

    func toggleFocus() {
        focused ? global.focusedPath.clear() : global.focusedPath.setFocus(node: nodeId)
    }

    func mergeNode() {
        if let mergableNodeId {
            let pathId = context.path.id
            global.documentUpdater.update(path: .merge(.init(pathId: pathId, endingNodeId: nodeId, mergedPathId: pathId, mergedEndingNodeId: mergableNodeId)))
        }
    }

    func setNodeType(_ nodeType: PathNodeType) {
        let pathId = context.path.id
        global.documentUpdater.update(pathProperty: .update(.init(pathId: pathId, kind: .setNodeType(.init(nodeIds: [nodeId], nodeType: nodeType)))))
    }

    func breakNode() {
        let pathId = context.path.id
        global.documentUpdater.update(path: .breakAtNode(.init(pathId: pathId, nodeId: nodeId, newNodeId: UUID(), newPathId: UUID())))
    }

    func deleteNode() {
        global.documentUpdater.update(focusedPath: .deleteNode(.init(nodeId: nodeId)))
    }
}

// MARK: - SegmentMenu

private struct SegmentMenu: View, TracedView, EquatableBy, ComputedSelectorHolder {
    let pathId: UUID, fromNodeId: UUID

    var equatableBy: some Equatable { pathId; fromNodeId }

    struct SelectorProps: Equatable { let pathId: UUID, fromNodeId: UUID }
    class Selector: SelectorBase {
        @Formula({ global.path.get(id: $0.pathId) }) static var path
        @Formula({ global.pathProperty.get(id: $0.pathId) }) static var property

        @Selected({ path($0)?.segment(fromId: $0.fromNodeId) }) var segment
        @Selected({ property($0)?.segmentType(id: $0.fromNodeId) }) var segmentType
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

private extension SegmentMenu {
    @ViewBuilder var content: some View {
        Label("\(fromNodeId)", systemImage: "number")
        Button(selector.focused ? "Unfocus" : "Focus", systemImage: selector.focused ? "circle.slash" : "scope") { toggleFocus() }

        Divider()

        ControlGroup { segmentTypeButtons } label: { Text("Segment Type") }

        Divider()

        Button("Split", systemImage: "square.and.line.vertical.and.square") { splitSegment() }

        Divider()

        Button("Break", systemImage: "scissors.circle", role: .destructive) { breakSegment() }
    }

    @ViewBuilder var segmentTypeButtons: some View {
        segmentTypeButton(.line)
        segmentTypeButton(.cubic)
        segmentTypeButton(.quadratic)
    }

    @ViewBuilder func segmentTypeButton(_ segmentType: PathSegmentType) -> some View {
        var name: String {
            switch segmentType {
            case .line: "Line"
            case .cubic: "Cubic Bezier"
            case .quadratic: "Quadratic Bezier"
            case .auto: ""
            }
        }
        let selected = selector.segmentType == segmentType
        Button(name, systemImage: selected ? "checkmark" : "") { selected ? setSegmentType(.auto) : setSegmentType(segmentType) }
    }

    func toggleFocus() {
        selector.focused ? global.focusedPath.clear() : global.focusedPath.setFocus(segment: fromNodeId)
    }

    func setSegmentType(_ segmentType: PathSegmentType) {
        global.documentUpdater.update(pathProperty: .update(.init(pathId: pathId, kind: .setSegmentType(.init(fromNodeIds: [fromNodeId], segmentType: segmentType)))))
    }

    func splitSegment() {
        guard let segment = selector.segment else { return }
        let paramT = segment.tessellated().approxPathParamT(lineParamT: 0.5).t
        let id = UUID()
        global.documentUpdater.update(focusedPath: .splitSegment(.init(fromNodeId: fromNodeId, paramT: paramT, newNodeId: id, offset: .zero)))
        global.focusedPath.setFocus(node: id)
    }

    func breakSegment() {
        if let pathId = global.activeItem.focusedItemId {
            global.documentUpdater.update(path: .breakAtSegment(.init(pathId: pathId, fromNodeId: fromNodeId, newPathId: UUID())))
        }
    }
}
