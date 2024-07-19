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
        .foregroundStyle(selector.focused ? .blue : .label)
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
}

// MARK: - NodeDetailPanel

private struct NodeDetailView: View, TracedView, EquatableBy, ComputedSelectorHolder {
    let pathId: UUID, nodeId: UUID

    var equatableBy: some Equatable { pathId; nodeId }

    struct SelectorProps: Equatable { let pathId: UUID, nodeId: UUID }
    class Selector: SelectorBase {
        @Formula({ global.path.get(id: $0.pathId) }) static var path
        @Formula({ global.pathProperty.get(id: $0.pathId) }) static var property
        @Formula({ path($0)?.nodeId(before: $0.nodeId) }) static var prevNodeId

        @Selected({ path($0)?.node(id: $0.nodeId) }) var node
        @Selected({ global.focusedPath.focusedNodeId == $0.nodeId }) var focused
        @Selected({ property($0)?.segmentType(id: $0.nodeId) }) var segmentType
        @Selected({ props in prevNodeId(props).map { property(props)?.segmentType(id: $0.id) } }) var prevSegmentType
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
            controlInRow
            positionRow
            controlOutRow
        }
        .background(.background.secondary)
        .clipRounded(radius: 12)
    }

    @ViewBuilder var positionRow: some View {
        if let node = selector.node {
            Divider()
            HStack {
                Menu { NodeMenu(pathId: pathId, nodeId: nodeId) } label: {
                    Text("Node")
                        .font(.callout)
                        .padding(12)
                }
                .menuOrder(.fixed)
                .tint(.label)
                .foregroundStyle(selector.focused ? .blue.opacity(0.8) : .label)
                Spacer(minLength: 12)
                PositionPicker(position: node.position) { updateNode(position: $0, pending: true) } onDone: { updateNode(position: $0) }
                    .padding(12)
            }
        }
    }

    @ViewBuilder var controlInRow: some View {
        if let node = selector.node {
            let segmentType = selector.prevSegmentType
            let isCubic = segmentType == .cubic || (segmentType == .auto && node.controlIn != .zero)
            let isLine = segmentType == .line || (segmentType == .auto && node.controlIn == .zero)
            HStack {
                let menu = EmptyView()
                if isCubic {
                    rowTitle(name: "Cubic", subname: "In")
                        .foregroundStyle(selector.focused ? .orange.opacity(0.8) : .label)
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
        if let node = selector.node {
            let segmentType = selector.segmentType
            let isCubic = segmentType == .cubic || (segmentType == .auto && node.controlOut != .zero)
            let isLine = segmentType == .line || (segmentType == .auto && node.controlOut == .zero)
            Divider()
            HStack {
                if isCubic {
                    rowTitle(name: "Cubic", subname: "Out")
                        .foregroundStyle(selector.focused ? .green.opacity(0.8) : .label)
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
        if var node = selector.node {
            position.map { node.position = $0 }
            controlIn.map { node.controlIn = $0 }
            controlOut.map { node.controlOut = $0 }
            global.documentUpdater.update(focusedPath: .setNode(.init(nodeId: nodeId, node: node)), pending: pending)
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

        @Selected({ path($0)?.mergableNodeId(id: $0.nodeId) }) var mergableNodeId
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
        if selector.mergableNodeId != nil {
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
        if let mergableNodeId = selector.mergableNodeId {
            global.documentUpdater.update(path: .merge(.init(pathId: pathId, endingNodeId: nodeId, mergedPathId: pathId, mergedEndingNodeId: mergableNodeId)))
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
