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
            PanelSection(name: "Nodes") {
                VStack(spacing: 0) {
                    ForEach(nodeIds) { nodeId in
                        NodeRow(context: context, nodeId: nodeId)
                        if nodeId != nodeIds.last {
                            Divider().padding(.leading, 12)
                        }
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
            detail
                .frame(height: expanded ? nil : 0, alignment: .top)
                .clipped()
        }
        .onChange(of: focused) {
            withAnimation(.fast) { expanded = focused }
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
                withAnimation(.fast) { expanded.toggle() }
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

    @ViewBuilder var detail: some View {
        if expanded {
            NodeDetailView(context: context, nodeId: nodeId)
                .padding(12)
        }
    }
}

// MARK: - NodeDetailPanel

private struct NodeDetailView: View, TracedView {
    let context: Context, nodeId: UUID

    @State private var showPopupIn = false
    @State private var showPopupNode = false
    @State private var showPopupOut = false

    @State private var pathNodeType: PathNodeType = .corner

    var body: some View { trace {
        content
    } }
}

// MARK: private

private extension NodeDetailView {
    var content: some View {
        HStack(spacing: 0) {
            buttonIn
            buttonDivider
            buttonNode
            buttonDivider
            buttonOut
        }
        .background(.ultraThickMaterial)
        .clipRounded(radius: 12)
    }

    var node: PathNode? { context.path.node(id: nodeId) }

    var focused: Bool { context.focusedNodeId == nodeId }

    var segmentType: PathSegmentType? { context.pathProperty.segmentType(id: nodeId) }

    var prevSegmentType: PathSegmentType? { context.path.nodeId(before: nodeId).map { context.pathProperty.segmentType(id: $0) }}

    @ViewBuilder var buttonIn: some View {
        var disabled: Bool { context.path.nodeId(before: nodeId) == nil }
        Button { showPopupIn.toggle() } label: { labelControl(isOut: false) }
            .disabled(disabled)
            .tint(.label)
            .portal(isPresented: $showPopupIn, configs: .init(isModal: true, align: .bottomInnerLeading, gap: .init(squared: 6))) {
                PathCurvePopup(pathId: context.path.id, nodeId: nodeId, isOut: false)
            }
    }

    @ViewBuilder var buttonNode: some View {
        Button { showPopupNode.toggle() } label: { labelNode }
            .tint(.label)
            .portal(isPresented: $showPopupNode, configs: .init(isModal: true, align: .bottomCenter, gap: .init(squared: 6))) {
                Text("Hello node button").padding().background(.regularMaterial)
            }
    }

    @ViewBuilder var buttonOut: some View {
        var disabled: Bool { context.path.nodeId(after: nodeId) == nil }
        Button { showPopupOut.toggle() } label: { labelControl(isOut: true) }
            .disabled(disabled)
            .tint(.label)
            .portal(isPresented: $showPopupOut, configs: .init(isModal: true, align: .bottomInnerTrailing, gap: .init(squared: 6))) {
                PathCurvePopup(pathId: context.path.id, nodeId: nodeId, isOut: true)
            }
    }

    @ViewBuilder var buttonDivider: some View {
        Divider().padding(6)
    }

    @ViewBuilder var labelNode: some View {
        let color = focused ? Color.blue : .label
        VStack(spacing: 0) {
            Image(systemName: "smallcircle.filled.circle")
                .frame(size: .init(squared: 20))
            Spacer()
            labelTitle(name: "Node", subname: nodeId.shortDescription)
                .font(.caption)
        }
        .foregroundStyle(color)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(6)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder func labelControl(isOut: Bool) -> some View {
        let disabled = isOut ? context.path.nodeId(after: nodeId) == nil : context.path.nodeId(before: nodeId) == nil,
            color = disabled ? Color.label.opacity(0.5) : !focused ? .label : isOut ? .green : .orange,
            segmentType = isOut ? segmentType : prevSegmentType,
            control = isOut ? node?.controlOut : node?.controlIn
        var activeSegmentType: PathSegmentType? {
            guard let segmentType else { return nil }
            guard segmentType != .auto else { return control == .zero ? .line : .cubic }
            return segmentType
        }
        var name: String {
            guard let activeSegmentType else { return "Terminal" }
            return activeSegmentType.name
        }
        var image: String {
            guard let activeSegmentType else { return "circle.slash" }
            switch activeSegmentType {
            case .line: return "line.diagonal"
            default: return "point.topleft.down.to.point.bottomright.curvepath"
            }
        }
        VStack(spacing: 0) {
            Image(systemName: image)
                .frame(size: .init(squared: 20))
            Spacer()
            labelTitle(name: name, subname: isOut ? "out" : "in")
        }
        .foregroundStyle(color)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(6)
        .fixedSize(horizontal: false, vertical: true)
    }

    func labelTitle(name: String, subname: String) -> some View {
        HStack(spacing: 0) {
            Text(name)
                .font(.caption)
            Text(subname)
                .font(.system(size: 8).monospaced())
                .baselineOffset(-4)
        }
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
