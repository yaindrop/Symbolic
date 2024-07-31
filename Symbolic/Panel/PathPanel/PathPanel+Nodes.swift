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
            PanelSection(name: "Nodes") {
                let nodeIds = context.path.nodeIds
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
            detail
        }
        .onChange(of: focused) {
            if focused {
                withAnimation(.fast) { expanded = true }
            }
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
            Button { toggleExpanded() } label: { expandIcon }
                .tint(.label)
        } deps: { expanded }
    }

    @ViewBuilder var expandIcon: some View {
        Image(systemName: expanded ? "chevron.up" : "chevron.down")
            .padding(12)
            .frame(maxHeight: .infinity)
    }

    @ViewBuilder var detail: some View {
        if expanded {
            NodeDetailView(context: context, nodeId: nodeId)
                .padding(12)
        }
    }

    func toggleFocus() {
        if focused {
            withAnimation(.fast) { expanded = false }
            global.focusedPath.clear()
        } else {
            global.focusedPath.setFocus(node: nodeId)
        }
    }

    func toggleExpanded() {
        withAnimation(.fast) { expanded.toggle() }
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
