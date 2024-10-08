import SwiftUI

private struct Context {
    var pathId: UUID
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
            @Selected({ global.activeItem.focusedPathId }) var pathId
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
        if let pathId = selector.pathId, let path = selector.path, let pathProperty = selector.pathProperty {
            .init(pathId: pathId, path: path, pathProperty: pathProperty, focusedNodeId: selector.focusedNodeId, selectingNodes: selector.selectingNodes, activeNodeIds: selector.activeNodeIds)
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
                withAnimation(.fast) { expanded = true }
            }
        }
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
            if selected {
                Image(systemName: "checkmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .blue)
                    .frame(maxHeight: .infinity)
            } else {
                Image(systemName: "circle")
                    .foregroundStyle(Color.label)
                    .frame(maxHeight: .infinity)
            }
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
            withAnimation(.fast) { expanded = false }
            global.focusedPath.selectionClear()
        } else {
            global.focusedPath.setFocus(node: nodeId)
        }
    }

    func toggleExpanded() {
        withAnimation(.fast) { expanded.toggle() }
    }

    func toggleSelection() {
        global.focusedPath.selection(toggle: [nodeId])
    }
}

// MARK: - NodeDetailView

private struct NodeDetailView: View, TracedView {
    @Environment(\.panelFloatingStyle) var floatingStyle
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
        case cubicIn, node, cubicOut
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
        .onChange(of: floatingStyle) { _, appearance in
            if !appearance.isPrimary {
                activePopover = nil
            }
        }
    }

    var node: PathNode? { context.path.node(id: nodeId) }

    var prevId: UUID? { context.path.nodeId(before: nodeId) }

    var focused: Bool { context.focusedNodeId == nodeId }

    var segmentType: PathSegmentType? { context.pathProperty.segmentType(id: nodeId) }

    var prevSegmentType: PathSegmentType? { prevId.map { context.pathProperty.segmentType(id: $0) } }

    var segment: PathSegment? { context.path.segment(fromId: nodeId) }

    var prevSegment: PathSegment? { prevId.map { context.path.segment(fromId: $0) } }

    @ViewBuilder var nodeButton: some View {
        let isPresented = $activePopover.predicate(.node, nil)
        Button { isPresented.wrappedValue.toggle() } label: { nodeLabel }
            .tint(.label)
            .portal(isPresented: isPresented, configs: .init(isModal: true, align: .bottomCenter, gap: .init(squared: 6))) {
                PathNodePopover(pathId: context.pathId, nodeId: nodeId)
            }
    }

    @ViewBuilder func controlButton(isOut: Bool) -> some View {
        let disabled = (isOut ? context.path.nodeId(after: nodeId) : context.path.nodeId(before: nodeId)) == nil,
            align: PlaneOuterAlign = isOut ? .bottomInnerTrailing : .bottomInnerLeading,
            isPresented = $activePopover.predicate(isOut ? .cubicOut : .cubicIn, nil)
        Button { isPresented.wrappedValue.toggle() } label: { controlLabel(isOut: isOut) }
            .disabled(disabled)
            .tint(.label)
            .portal(isPresented: isPresented, configs: .init(isModal: true, align: align, gap: .init(squared: 6))) {
                PathSegmentPopover(pathId: context.pathId, nodeId: nodeId, isOut: isOut)
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
            segment = isOut ? segment : prevSegment,
            segmentType = isOut ? segmentType : prevSegmentType,
            activeType = segment.map { segmentType?.activeType(segment: $0) }
        var name: String {
            guard !disabled,
                  let activeType else { return "Terminal" }
            return activeType.name
        }
        var image: String {
            guard !disabled,
                  let activeType = activeType else { return "circle.slash" }
            return "point.topleft.down.to.point.bottomright.curvepath"
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
