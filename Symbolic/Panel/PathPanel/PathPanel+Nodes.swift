import SwiftUI

private struct Context {
    var path: Path
    var pathProperty: PathProperty
    var focusedNodeId: UUID?
    var selectingNodes: Bool
    var activeNodeIds: Set<UUID>
}

// MARK: - Nodes

extension PathPanel {
    struct Nodes: View, SelectorHolder {
        class Selector: SelectorBase {
            @Selected({ global.activeItem.focusedPath }) var path
            @Selected({ global.activeItem.focusedPathProperty }) var pathProperty
            @Selected({ global.focusedPath.focusedNodeId }) var focusedNodeId
            @Selected({ global.focusedPath.selectingNodes }) var selectingNodes
            @Selected({ global.focusedPath.activeNodeIds }) var activeNodeIds
        }

        @SelectorWrapper var selector

        var body: some View {
            setupSelector {
                content
            }
        }
    }
}

// MARK: private

private extension PathPanel.Nodes {
    @ViewBuilder var content: some View {
        if let context {
            PanelSection(name: "Nodes") {
                let nodeIds = context.path.nodeIds
                ForEach(nodeIds) { nodeId in
                    NodeRow(context: context, nodeId: nodeId)
                    if nodeId != nodeIds.last {
                        ContextualDivider()
                    }
                }
            }
        }
    }

    var context: Context? {
        if let path = selector.path, let pathProperty = selector.pathProperty {
            .init(path: path, pathProperty: pathProperty, focusedNodeId: selector.focusedNodeId, selectingNodes: selector.selectingNodes, activeNodeIds: selector.activeNodeIds)
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
            ContextualRow {
                leadingButton
                Spacer()
                trailingButton
            }
            if expanded && !context.selectingNodes {
                NodeDetailView(context: context, nodeId: nodeId)
                    .padding(12)
            }
        }
        .onChange(of: focused) {
            if focused {
                expanded = true
            }
        }
        .animation(.fast, value: expanded)
        .animation(.fast, value: context.selectingNodes)
    }

    var focused: Bool { context.focusedNodeId == nodeId }

    var selected: Bool { context.activeNodeIds.contains(nodeId) }

    @ViewBuilder var leadingButton: some View {
        Button { toggleFocus() } label: { name }
            .tint(.label)
    }

    @ViewBuilder var name: some View {
        Memo {
            HStack {
                Image(systemName: "smallcircle.filled.circle")
                Text("\(nodeId.shortDescription)")
                    .contextualFont()
            }
            .foregroundStyle(focused ? .blue : .label)
            .frame(maxHeight: .infinity)
        } deps: { nodeId; focused }
    }

    @ViewBuilder var trailingButton: some View {
        if context.selectingNodes {
            Button { toggleSelection() } label: { selectIcon }
                .tint(.label)
        } else {
            Button { toggleExpanded() } label: { expandIcon }
                .tint(.label)
        }
    }

    @ViewBuilder var selectIcon: some View {
        Memo {
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .symbolRenderingMode(.palette)
                .foregroundStyle(Color.label, .blue)
                .frame(maxHeight: .infinity)
        } deps: { selected }
    }

    @ViewBuilder var expandIcon: some View {
        Memo {
            Image(systemName: expanded ? "chevron.up" : "chevron.down")
                .frame(maxHeight: .infinity)
        } deps: { expanded }
    }

    func toggleFocus() {
        if focused {
            expanded = false
            global.focusedPath.clear()
        } else {
            global.focusedPath.setFocus(node: nodeId)
        }
    }

    func toggleExpanded() {
        expanded.toggle()
    }

    func toggleSelection() {
        global.focusedPath.toggleSelection(nodeIds: [nodeId])
    }
}

// MARK: - NodeDetailView

private struct NodeDetailView: View, TracedView {
    @Environment(\.panelScrollFrame) var panelScrollFrame
    @Environment(\.panelAppearance) var panelAppearance
    let context: Context, nodeId: UUID

    @State private var activePopover: ActivePopover?

    @State private var frame: CGRect = .zero

    var body: some View { trace {
        content
    } }
}

// MARK: private

private extension NodeDetailView {
    enum ActivePopover {
        case controlIn, node, controlOut
    }

    var content: some View {
        HStack(spacing: 0) {
            controlButton(isOut: false)
            buttonDivider
            nodeButton
            buttonDivider
            controlButton(isOut: true)
        }
        .background(.ultraThickMaterial)
        .clipRounded(radius: 12)
        .geometryReader { frame = $0.frame(in: .global) }
        .onChange(of: panelScrollFrame.contains(frame)) { _, contains in
            if !contains {
                activePopover = nil
            }
        }
        .onChange(of: panelAppearance) { _, appearance in
            if appearance != .floatingPrimary, appearance != .popoverSection {
                activePopover = nil
            }
        }
    }

    var node: PathNode? { context.path.node(id: nodeId) }

    var focused: Bool { context.focusedNodeId == nodeId }

    var segmentType: PathSegmentType? { context.pathProperty.segmentType(id: nodeId) }

    var prevSegmentType: PathSegmentType? { context.path.nodeId(before: nodeId).map { context.pathProperty.segmentType(id: $0) }}

    @ViewBuilder var nodeButton: some View {
        let isPresented = $activePopover.predicate(.node, nil)
        Button { isPresented.wrappedValue.toggle() } label: { nodeLabel }
            .tint(.label)
            .portal(isPresented: isPresented, configs: .init(align: .bottomCenter, gap: .init(squared: 6))) {
                PathNodePopover(pathId: context.path.id, nodeId: nodeId)
            }
    }

    @ViewBuilder func controlButton(isOut: Bool) -> some View {
        let disabled = (isOut ? context.path.nodeId(after: nodeId) : context.path.nodeId(before: nodeId)) == nil,
            align: PlaneOuterAlign = isOut ? .bottomInnerTrailing : .bottomInnerLeading,
            isPresented = $activePopover.predicate(isOut ? .controlOut : .controlIn, nil)
        Button { isPresented.wrappedValue.toggle() } label: { controlLabel(isOut: isOut) }
            .disabled(disabled)
            .tint(.label)
            .portal(isPresented: isPresented, configs: .init(align: align, gap: .init(squared: 6))) {
                PathCurvePopover(pathId: context.path.id, nodeId: nodeId, isOut: isOut)
            }
    }

    var buttonDivider: some View {
        Divider().padding(6)
    }

    @ViewBuilder var nodeLabel: some View {
        let color = focused ? Color.blue : .label
        VStack(spacing: 0) {
            PathNodeThumbnail(path: context.path, pathProperty: context.pathProperty, nodeId: nodeId)
            Spacer()
            labelTitle(name: "Node", subname: nodeId.shortDescription)
                .font(.caption)
        }
        .foregroundStyle(color)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(6)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder func controlLabel(isOut: Bool) -> some View {
        let disabled = isOut ? context.path.nodeId(after: nodeId) == nil : context.path.nodeId(before: nodeId) == nil,
            color = disabled ? Color.label.opacity(0.5) : !focused ? .label : isOut ? .green : .orange,
            segmentType = isOut ? segmentType : prevSegmentType,
            control = isOut ? node?.controlOut : node?.controlIn
        var name: String {
            guard !disabled,
                  let control,
                  let segmentType = segmentType?.activeType(control: control) else { return "Terminal" }
            return segmentType.name
        }
        var image: String {
            guard !disabled,
                  let control,
                  let segmentType = segmentType?.activeType(control: control) else { return "circle.slash" }
            switch segmentType {
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
}
